group "default" {
  targets = ["meuse"]
}

target "meuse" {
  context = "."
  dockerfile = "Dockerfile"
  cache-from = ["type=local,src=./.buildcache"]
  cache-to = ["type=local,dest=./.buildcache,mode=max"]
}