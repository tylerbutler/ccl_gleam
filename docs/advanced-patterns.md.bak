# Advanced CCL Patterns

Complex configuration patterns and best practices for CCL.

## Complex Nested Section Structures

### Multi-Level Nesting

Build deeply nested configurations for complex applications:

```ccl
application =
  name = MyApp
  version = 2.1.0
  
  server =
    host = 0.0.0.0
    port = 8080
    
    ssl =
      enabled = true
      cert_file = /etc/ssl/cert.pem
      key_file = /etc/ssl/private.key
      
    middleware =
      cors =
        enabled = true
        origins =
          = https://app.example.com
          = https://admin.example.com
      
      rate_limiting =
        enabled = true
        requests_per_minute = 1000
        
  database =
    primary =
      host = db-primary.example.com
      port = 5432
      pool_size = 20
      
    replica =
      host = db-replica.example.com
      port = 5432
      pool_size = 10
```

### Environment-Specific Configuration

Structure configuration by environment using nested sections:

```ccl
development =
  debug = true
  log_level = debug
  
  database =
    host = localhost
    port = 5432
    pool_size = 5
  
  cache =
    enabled = false

production =
  debug = false
  log_level = warning
  
  database =
    host = prod-db.example.com
    port = 5432
    pool_size = 20
    ssl = true
  
  cache =
    enabled = true
    
    redis =
      host = redis-cluster.example.com
      port = 6379
```

Access environment-specific config in Gleam:

```gleam
pub fn load_env_config(config: ccl.CCL, environment: String) -> DatabaseConfig {
  let env_path = environment <> ".database"
  
  let host = ccl.get(config, env_path <> ".host")
    |> result.map(fn(val) { 
      case val { 
        ccl.CclString(h) -> h
        _ -> "localhost" 
      }
    })
    |> result.unwrap("localhost")
    
  let pool_size = ccl.get(config, env_path <> ".pool_size")
    |> result.try(fn(val) {
      case val {
        ccl.CclString(s) -> int.parse(s)
        _ -> Error(Nil)
      }
    })
    |> result.unwrap(10)
    
  DatabaseConfig(host: host, pool_size: pool_size)
}
```

## Advanced List Patterns

### Lists with Metadata

Combine lists with structured metadata:

```ccl
services =
  web_servers =
    = web-1.example.com
    = web-2.example.com
    = web-3.example.com
    
  server_config =
    web-1.example.com =
      region = us-east-1
      capacity = high
      
    web-2.example.com =
      region = us-west-2
      capacity = medium
      
    web-3.example.com =
      region = eu-west-1
      capacity = high

feature_flags =
  enabled =
    = user_registration
    = email_notifications
    = advanced_search
  
  beta =
    = new_dashboard
    = ai_recommendations
    
  config =
    user_registration =
      rollout_percentage = 100
      regions =
        = us-east-1
        = us-west-2
        
    new_dashboard =
      rollout_percentage = 25
      user_types =
        = premium
        = enterprise
```

### Complex List Processing

Process lists with associated metadata:

```gleam
pub fn load_servers_with_config(config: ccl.CCL) -> List(ServerInfo) {
  case ccl.get(config, "services.web_servers") {
    Ok(ccl.CclList(servers)) -> {
      list.map(servers, fn(server_name) {
        let config_path = "services.server_config." <> server_name
        
        let region = ccl.get(config, config_path <> ".region")
          |> result.map(fn(val) { 
            case val { ccl.CclString(r) -> r; _ -> "unknown" }
          })
          |> result.unwrap("unknown")
          
        let capacity = ccl.get(config, config_path <> ".capacity")
          |> result.map(fn(val) { 
            case val { ccl.CclString(c) -> c; _ -> "medium" }
          })
          |> result.unwrap("medium")
          
        ServerInfo(
          name: server_name,
          region: region, 
          capacity: capacity
        )
      })
    }
    _ -> []
  }
}
```

## Documentation and Comments

### Comprehensive Documentation

Use comment keys for rich documentation:

```ccl
/= Application Configuration
/= Version: 2.1.0
/= Last updated: 2024-01-15
/= 
/= This configuration supports multiple environments
/= and automatic failover between database instances

api =
  /= Rate limiting configuration
  /= Controls the number of requests per minute per IP address
  rate_limit = 100
  
  /= Request timeout in seconds
  /= Increase this value if you have slow external API calls
  timeout = 30.0
  
  authentication =
    /= JWT secret key - MUST be changed in production
    /= Generate with: openssl rand -base64 32
    jwt_secret = your-super-secret-key-here
    
    /= Token expiration time in seconds (1 hour = 3600)
    jwt_expiration = 3600

database =
  /= Primary database connection
  /= This is the main read-write database
  primary =
    host = localhost
    port = 5432
    /= Maximum connections in the connection pool
    /= Adjust based on your application's concurrency needs
    pool_size = 20
    
  /= Read-only replica for scaling read operations  
  /= Automatically used for SELECT queries when available
  replica =
    host = replica.example.com
    port = 5432
    pool_size = 10
    /= Enable SSL for replica connections in production
    ssl_mode = prefer
```

### Comment Filtering

Filter out documentation when processing configuration:

```gleam
pub fn filter_comments(config: ccl.CCL) -> ccl.CCL {
  // Remove special comment keys
  let comment_keys = ["/", "//", "#", "/*", "doc", "comment"]
  ccl.filter_keys(config, comment_keys)
}

pub fn extract_documentation(config: ccl.CCL) -> List(#(String, String)) {
  ccl.get_all_paths(config)
  |> list.filter_map(fn(path) {
    case string.starts_with(path, "/") || string.starts_with(path, "#") {
      True -> {
        case ccl.get(config, path) {
          Ok(ccl.CclString(doc)) -> Ok(#(path, doc))
          _ -> Error(Nil)
        }
      }
      False -> Error(Nil)
    }
  })
}
```

## Migration Patterns

### Gradual Migration from JSON

Support both CCL and JSON during migration:

```gleam
pub type ConfigSource {
  CclSource(String)
  JsonSource(String)
}

pub fn load_config(source: ConfigSource) -> Result(AppConfig, String) {
  case source {
    CclSource(ccl_text) -> load_from_ccl(ccl_text)
    JsonSource(json_text) -> load_from_json(json_text)
  }
}

pub fn load_from_ccl(ccl_text: String) -> Result(AppConfig, String) {
  use entries <- result.try(ccl.parse(ccl_text))
  let config = ccl.make_objects(entries)
  
  use database_host <- result.try(ccl.get(config, "database.host"))
  use port_str <- result.try(ccl.get(config, "server.port"))
  use port <- result.try(case port_str {
    ccl.CclString(s) -> int.parse(s) |> result.map_error(fn(_) { "Invalid port" })
    _ -> Error("Port must be string")
  })
  
  case database_host {
    ccl.CclString(host) -> Ok(AppConfig(database_host: host, server_port: port))
    _ -> Error("Database host must be string")
  }
}
```

### Complex Data Transformations

Transform nested CCL into application-specific structures:

```ccl
microservices =
  user_service =
    replicas = 3
    resources =
      cpu = 500m
      memory = 1Gi
    endpoints =
      = /api/users
      = /api/profiles
      
  auth_service =
    replicas = 2
    resources =
      cpu = 200m
      memory = 512Mi
    endpoints =
      = /api/auth
      = /api/tokens
```

```gleam
pub type ServiceConfig {
  ServiceConfig(
    name: String,
    replicas: Int,
    cpu: String,
    memory: String,
    endpoints: List(String)
  )
}

pub fn load_microservices(config: ccl.CCL) -> List(ServiceConfig) {
  case ccl.get(config, "microservices") {
    Ok(ccl.CclObject(services_config)) -> {
      ccl.get_all_paths(services_config)
      |> list.filter(fn(path) { !string.contains(path, ".") })
      |> list.filter_map(fn(service_name) {
        case ccl.get(services_config, service_name) {
          Ok(ccl.CclObject(service_config)) -> {
            case load_single_service(service_name, service_config) {
              Ok(service) -> Ok(service)
              Error(_) -> Error(Nil)
            }
          }
          _ -> Error(Nil)
        }
      })
    }
    _ -> []
  }
}

fn load_single_service(name: String, config: ccl.CCL) -> Result(ServiceConfig, String) {
  use replicas_str <- result.try(case ccl.get(config, "replicas") {
    Ok(ccl.CclString(s)) -> Ok(s)
    _ -> Error("Missing replicas")
  })
  
  use replicas <- result.try(int.parse(replicas_str) |> result.map_error(fn(_) { "Invalid replicas" }))
  
  use cpu <- result.try(case ccl.get(config, "resources.cpu") {
    Ok(ccl.CclString(c)) -> Ok(c)
    _ -> Error("Missing CPU")
  })
  
  use memory <- result.try(case ccl.get(config, "resources.memory") {
    Ok(ccl.CclString(m)) -> Ok(m)
    _ -> Error("Missing memory")
  })
  
  let endpoints = case ccl.get(config, "endpoints") {
    Ok(ccl.CclList(ep)) -> ep
    _ -> []
  }
  
  Ok(ServiceConfig(
    name: name,
    replicas: replicas,
    cpu: cpu,
    memory: memory,
    endpoints: endpoints
  ))
}
```

## Performance Considerations

### Large Configuration Files

For very large configuration files, consider selective parsing:

```gleam
pub fn load_section_only(ccl_text: String, section: String) -> Result(ccl.CCL, String) {
  use entries <- result.try(ccl.parse(ccl_text))
  let all_config = ccl.make_objects(entries)
  
  case ccl.get(all_config, section) {
    Ok(ccl.CclObject(section_config)) -> Ok(section_config)
    _ -> Error("Section not found: " <> section)
  }
}

// Usage: Load only database config from a large file
let database_config = load_section_only(large_config_text, "database")
```

### Caching Parsed Configuration

Cache parsed configuration to avoid re-parsing:

```gleam
pub type ConfigCache {
  ConfigCache(
    raw_text: String,
    parsed_config: ccl.CCL,
    last_modified: Int
  )
}

pub fn load_with_cache(
  config_file: String, 
  cache: Option(ConfigCache)
) -> Result(#(ccl.CCL, ConfigCache), String) {
  use file_content <- result.try(simplifile.read(config_file))
  
  case cache {
    Some(cached) if cached.raw_text == file_content -> {
      Ok(#(cached.parsed_config, cached))
    }
    _ -> {
      use entries <- result.try(ccl.parse(file_content))
      let config = ccl.make_objects(entries)
      let new_cache = ConfigCache(
        raw_text: file_content,
        parsed_config: config,
        last_modified: system_time()
      )
      Ok(#(config, new_cache))
    }
  }
}
```

## Best Practices

1. **Use Comments Liberally** - Document complex configurations with `/ =` keys
2. **Choose Consistent Structure** - Either nested sections or dot notation, not mixed
3. **Validate Early** - Parse and validate configuration at application startup
4. **Provide Defaults** - Handle missing configuration gracefully with sensible defaults
5. **Environment-Specific Sections** - Use nested sections for different deployment environments
6. **Test Configuration** - Unit test your configuration loading code with various inputs