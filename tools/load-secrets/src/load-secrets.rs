use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use serde::{Deserialize, Serialize};
use tokio::process::Command as AsyncCommand;
use tokio::runtime::Runtime;
use anyhow::{Context, Result};

#[derive(Serialize, Deserialize)]
struct CachedSecret {
    timestamp: u64,
    value: String,
}

struct SecretCache {
    cache_dir: PathBuf,
    ttl_minutes: u64,
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
        
        Ok(Self {
            cache_dir,
            ttl_minutes,
        })
    }

    fn get_cache_path(&self, item: &str) -> PathBuf {
        let mut path = self.cache_dir.clone();
        path.push(format!("{:x}", md5::compute(item)));
        path.set_extension("json");
        path
    }

    fn get(&self, item: &str) -> Option<String> {
        let cache_path = self.get_cache_path(item);
        if !cache_path.exists() {
            return None;
        }

        match fs::read_to_string(&cache_path) {
            Ok(content) => {
                match serde_json::from_str::<CachedSecret>(&content) {
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
        
        let content = serde_json::to_string(&cached)?;
        fs::write(&cache_path, content)
            .with_context(|| format!("Failed to write cache file: {:?}", cache_path))
    }
}

async fn run_op_command(args: &[&str]) -> Result<String> {
    let output = AsyncCommand::new("op")
        .args(args)
        .output()
        .await
        .context("Failed to execute op command")?;

    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        let error = String::from_utf8_lossy(&output.stderr);
        Err(anyhow::anyhow!("op command failed: {}", error))
    }
}

async fn read_secret(item: &str, cache: &SecretCache) -> Result<Option<String>> {
    // Try cache first
    if let Some(cached_value) = cache.get(item) {
        eprintln!("[DEBUG] Cache hit for: {}", item);
        return Ok(Some(cached_value));
    }

    // If not in cache, read from 1Password
    match run_op_command(&["read", item]).await {
        Ok(result) => {
            eprintln!("[DEBUG] Successfully read: {}", item);
            cache.set(item, &result)?;
            Ok(Some(result))
        }
        Err(e) => {
            eprintln!("[DEBUG] Failed to read: {}: {}", item, e);
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

    // Sign in to 1Password
    let signin_output = AsyncCommand::new("op")
        .arg("signin")
        .output()
        .await
        .context("Failed to execute op signin")?;

    if !signin_output.status.success() {
        eprintln!("Failed to sign in to 1Password");
        std::process::exit(1);
    }

    if debug {
        eprintln!("[DEBUG] 1Password signin completed");
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
        let cache = &cache;
        handles.push(tokio::spawn(async move {
            read_secret(item, cache).await
        }));
    }

    let results = futures::future::join_all(handles).await;

    // Process results
    let mut secrets = HashMap::new();
    for (item, result) in items.iter().zip(results) {
        if let Ok(Some(value)) = result.unwrap() {
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
