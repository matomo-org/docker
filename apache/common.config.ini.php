[General]
proxy_client_headers[] = HTTP_X_FORWARDED_FOR
proxy_host_headers[] = HTTP_X_FORWARDED_HOST

[Plugins]
Plugins[] = "EnvironmentVariables"
Plugins[] = "QueuedTracking"
Plugins[] = "CustomDimensions"

[PluginsInstalled]
PluginsInstalled[] = "EnvironmentVariables"
PluginsInstalled[] = "QueuedTracking"
PluginsInstalled[] = "CustomDimensions"

[QueuedTracking]
notify_queue_threshold_single_queue = ""
backend = ""
redisDatabase = ""
queueEnabled = ""
redisHost = ""
sentinelMasterName = ""
