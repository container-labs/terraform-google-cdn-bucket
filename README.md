# terraform-gcp-cdn-bucket

### TODO

+ right now this provisions the backend bucket in the same project at the load balancers and network
  + this doesn't feel right. The managed zone should be in networking
  + then all this other jaz either in the app project or a service project
  + that just has the ability to write A records to the core managed zone
