use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use tokio::process::Command as AsyncCommand;
use anyhow::{Context, Result};
use aes_gcm::{
    aead::{Aead, KeyInit},
    Aes256Gcm, Key,
};
use rand::{Rng, rngs::OsRng};
use aes_gcm::aead::generic_array::GenericArray;

#[derive(Serialize, Deserialize)]
struct CachedSecret {
    timestamp: u64,
    value: String,
}

#[derive(Clone)]
struct SecretCache {
    cache_dir: PathBuf,
    ttl_minutes: u64,
    cipher: Aes256Gcm,
}

impl SecretCache {
    fn new(cache_dir: Option<PathBuf>, ttl_minutes: u64) -> Result<Self> {
        let cache_dir = cache_dir.unwrap_or_else(|| {
            let mut home = dirs::home_dir().expect("Could not find home directory");
            home.push(".cache");
            home.push("op-secrets");
            home
        });
        
        fs::create_dir_all(&cache_dir)
            .with_context(|| format!("Failed to create cache directory: {:?}", cache_dir))?;

        // Generate or load encryption key
        let key_path = cache_dir.join(".key");
        let key = if key_path.exists() {
            let key_data = fs::read(&key_path)
                .with_context(|| "Failed to read encryption key")?;
            Key::<Aes256Gcm>::clone_from_slice(&key_data)
        } else {
            let mut key_bytes = [0u8; 32];
            OsRng.fill(&mut key_bytes);
            let key = Key::<Aes256Gcm>::clone_from_slice(&key_bytes);
            fs::write(&key_path, key_bytes)
                .with_context(|| "Failed to write encryption key")?;
            key
        };
        
        let cipher = Aes256Gcm::new(&key);
        
        Ok(Self {
            cache_dir,
            ttl_minutes,
            cipher,
        })
    }

    fn get_cache_path(&self, item: &str) -> PathBuf {
        let mut path = self.cache_dir.clone();
        path.push(format!("{:x}", md5::compute(item)));
        path.set_extension("enc");
        path
    }

    fn get(&self, item: &str) -> Option<String> {
        let cache_path = self.get_cache_path(item);
        if !cache_path.exists() {
            return None;
        }

        match fs::read(&cache_path) {
            Ok(encrypted_data) => {
                // First 12 bytes are the nonce
                if encrypted_data.len() < 12 {
                    let _ = fs::remove_file(&cache_path);
                    return None;
                }
                
                let (nonce_bytes, ciphertext) = encrypted_data.split_at(12);
                let nonce = GenericArray::clone_from_slice(nonce_bytes);
                
                match self.cipher.decrypt(&nonce, ciphertext) {
                    Ok(decrypted_data) => {
                        match serde_json::from_str::<CachedSecret>(&String::from_utf8_lossy(&decrypted_data)) {
                            Ok(cached) => {
                                let now = SystemTime::now()
                                    .duration_since(UNIX_EPOCH)
                                    .unwrap()
                                    .as_secs();
                                
                                if now - cached.timestamp > self.ttl_minutes * 60 {
                                    let _ = fs::remove_file(&cache_path);
                                    None
                                } else {
                                    Some(cached.value)
                                }
                            }
                            Err(_) => {
                                let _ = fs::remove_file(&cache_path);
                                None
                            }
                        }
                    }
                    Err(_) => {
                        let _ = fs::remove_file(&cache_path);
                        None
                    }
                }
            }
            Err(_) => None,
        }
    }

    fn set(&self, item: &str, value: &str) -> Result<()> {
        let cache_path = self.get_cache_path(item);
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs();
        
        let cached = CachedSecret {
            timestamp,
            value: value.to_string(),
        };
        
        let json_data = serde_json::to_string(&cached)?;
        
        // Generate a random nonce
        let mut nonce_bytes = [0u8; 12];
        OsRng.fill(&mut nonce_bytes);
        let nonce = GenericArray::clone_from_slice(&nonce_bytes);
        
        // Encrypt the data
        let ciphertext = self.cipher.encrypt(&nonce, json_data.as_bytes())
            .map_err(|e| anyhow::anyhow!("Failed to encrypt cache data: {}", e))?;
        
        // Combine nonce and ciphertext
        let mut encrypted_data = nonce_bytes.to_vec();
        encrypted_data.extend_from_slice(&ciphertext);
        
        fs::write(&cache_path, encrypted_data)
            .with_context(|| format!("Failed to write cache file: {:?}", cache_path))
    }
}

async fn run_op_command(args: &[&str]) -> Result<String> {
    if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
        eprintln!("[DEBUG] Running op command with args: {:?}", args);
    }

    let mut command = AsyncCommand::new("op");
    command.args(args);
    
    // Add a timeout of 10 seconds for the command
    let output = tokio::time::timeout(
        std::time::Duration::from_secs(10),
        command.output()
    ).await
    .context("Command timed out after 10 seconds")?
    .context("Failed to execute op command")?;

    if output.status.success() {
        let result = String::from_utf8_lossy(&output.stdout).trim().to_string();
        if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
            eprintln!("[DEBUG] Command succeeded with output: {}", result);
        }
        Ok(result)
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
            eprintln!("[DEBUG] Command failed with error: {}", error);
        }
        if error.contains("You are not currently signed in") {
            // Try to sign in again
            if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                eprintln!("[DEBUG] Attempting to sign in to 1Password");
            }
            
            // Add timeout for signin command
            let signin_output = tokio::time::timeout(
                std::time::Duration::from_secs(10),
                AsyncCommand::new("op")
                    .arg("signin")
                    .output()
            ).await
            .context("Signin command timed out after 10 seconds")?
            .context("Failed to execute op signin")?;

            if !signin_output.status.success() {
                let signin_error = String::from_utf8_lossy(&signin_output.stderr);
                if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                    eprintln!("[DEBUG] Sign in failed: {}", signin_error);
                }
                return Err(anyhow::anyhow!("Failed to sign in to 1Password: {}", signin_error));
            }

            if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                eprintln!("[DEBUG] Sign in successful, retrying original command");
            }

            // Retry the original command after successful sign in
            let retry_output = tokio::time::timeout(
                std::time::Duration::from_secs(10),
                AsyncCommand::new("op")
                    .args(args)
                    .output()
            ).await
            .context("Retry command timed out after 10 seconds")?
            .context("Failed to execute op command after signin")?;

            if retry_output.status.success() {
                let result = String::from_utf8_lossy(&retry_output.stdout).trim().to_string();
                if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                    eprintln!("[DEBUG] Retry succeeded with output: {}", result);
                }
                Ok(result)
            } else {
                let retry_error = String::from_utf8_lossy(&retry_output.stderr);
                if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                    eprintln!("[DEBUG] Retry failed with error: {}", retry_error);
                }
                Err(anyhow::anyhow!("op command failed after signin: {}", retry_error))
            }
        } else {
            Err(anyhow::anyhow!("op command failed: {}", error))
        }
    }
}

async fn read_secret(item: &str, cache: &SecretCache) -> Result<Option<String>> {
    if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
        eprintln!("[DEBUG] Attempting to read secret: {}", item);
    }

    // Try cache first
    if let Some(cached_value) = cache.get(item) {
        if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
            eprintln!("[DEBUG] Cache hit for: {}", item);
        }
        return Ok(Some(cached_value));
    }

    // If not in cache, read from 1Password
    match run_op_command(&["read", item]).await {
        Ok(result) => {
            if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                eprintln!("[DEBUG] Successfully read: {}", item);
            }
            cache.set(item, &result)?;
            Ok(Some(result))
        }
        Err(e) => {
            if env::var("DEBUG").map_or(false, |v| v == "1" || v == "true") {
                eprintln!("[DEBUG] Failed to read: {}: {}", item, e);
            }
            Ok(None)
        }
    }
}

#[tokio::main]
async fn main() -> Result<()> {
    let debug = env::var("DEBUG").map_or(false, |v| v == "1" || v == "true");
    
    if debug {
        eprintln!("[DEBUG] Starting 1Password secrets loading");
    }

    // Set up 1Password account
    env::set_var("OP_ACCOUNT", "foxcorporation.1password.com");
    if debug {
        eprintln!("[DEBUG] Using 1Password account: {}", env::var("OP_ACCOUNT").unwrap());
    }

    // Set email
    let user = env::var("USER").unwrap_or_default();
    let fox_email = format!("{}%40fox.com", user);
    env::set_var("FOX_EMAIL", &fox_email);
    if debug {
        eprintln!("[DEBUG] Set FOX_EMAIL to: {}", fox_email);
    }

    // Initialize cache
    let cache = SecretCache::new(None, 30)?;

    // Define items to read
    let items = [
        "op://Private/github-token/credential",
        "op://Private/confluence-token/username",
        "op://Private/confluence-token/credential",
        "op://Private/ATLASSIAN_API_TOKEN/credential",
        "op://Employee/Artifactory DPE/credential",
    ];

    // Read all secrets in parallel
    let mut handles = Vec::new();
    for item in items.iter() {
        let item = item.to_string();
        let cache = cache.clone();
        handles.push(tokio::spawn(async move {
            read_secret(&item, &cache).await
        }));
    }

    let results = futures::future::join_all(handles).await;

    // Process results
    let mut secrets = HashMap::new();
    for (item, result) in items.iter().zip(results) {
        match result {
            Ok(Ok(Some(value))) => {
                if debug {
                    eprintln!("[DEBUG] Successfully processed secret for: {}", item);
                }
                match *item {
                    item if item.contains("github-token") => {
                        secrets.insert("GITHUB_TOKEN", value);
                    }
                    item if item.contains("confluence-token/username") => {
                        secrets.insert("CONFLUENCE_USER", value);
                    }
                    item if item.contains("confluence-token/credential") => {
                        secrets.insert("CONFLUENCE_API_TOKEN", value);
                    }
                    item if item.contains("ATLASSIAN_API_TOKEN") => {
                        let value_clone = value.clone();
                        secrets.insert("ATLASSIAN_TOKEN", value);
                        secrets.insert("JIRA_API_TOKEN", value_clone);
                    }
                    item if item.contains("Artifactory") => {
                        secrets.insert("ARTIFACTORY_TOKEN", value);
                    }
                    _ => {}
                }
            }
            Ok(Ok(None)) => {
                if debug {
                    eprintln!("[DEBUG] No value found for: {}", item);
                }
            }
            Ok(Err(e)) => {
                eprintln!("Error processing {}: {}", item, e);
            }
            Err(e) => {
                eprintln!("Task failed for {}: {}", item, e);
            }
        }
    }

    // Output the secrets as shell export commands
    for (key, value) in secrets {
        println!("export {}='{}'", key, value);
    }

    if debug {
        eprintln!("[DEBUG] Completed loading all secrets");
    }

    Ok(())
} 
