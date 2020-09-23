[General]
proxy_client_headers[] = HTTP_X_FORWARDED_FOR
proxy_host_headers[] = HTTP_X_FORWARDED_HOST

[Plugins]
Plugins[] = "EnvironmentVariables"
Plugins[] = "QueuedTracking"

[PluginsInstalled]
PluginsInstalled[] = "EnvironmentVariables"
PluginsInstalled[] = "QueuedTracking"
