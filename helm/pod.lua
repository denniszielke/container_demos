function create_alpine_pod(_)
    local pod = {
      apiVersion = "v1",
      kind = "Pod",
      metadata = {
        name = alpine_fullname(_),
        labels = {
          heritage = _.Release.Service or "helm",
          release = _.Release.Name,
          chart = _.Chart.Name .. "-" .. _.Chart.Version,
          app = alpine_name(_)
        }
      },
      spec = {
        restartPolicy = _.Values.restartPolicy,
        containers = {
          {
            name = waiter,
            image = _.Values.image.repository .. ":" .. _.Values.image.tag,
            imagePullPolicy = _.Values.image.pullPolicy,
            command = {
              "/bin/sleep",
              "9000"
            }
          }
        }
      }
    }
    _.resources.add(pod)
  end