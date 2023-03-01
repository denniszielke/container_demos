//dependencies
const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");

//path to our proto file
const PROTO_FILE = "./service_def.proto";

//options needed for loading Proto file
const options = {
    keepCase: true,
    longs: String,
    enums: String,
    defaults: true,
    oneofs: true,
  };
  
  
  const pkgDefs = protoLoader.loadSync(PROTO_FILE, options);
  
  //load Definition into gRPC
  const userProto = grpc.loadPackageDefinition(pkgDefs);
  
  //create gRPC server
  const server = new grpc.Server();
  
  //implement UserService
  server.addService(userProto.UserService.service, {
    //implment GetUser
    GetUser: (input, callback) => {
      try {
        callback(null, { name: "Dennis", age: 25 });
      } catch (error) {
        callback(error, null);
      }
    },
  });
  
  
  //start the Server
  server.bindAsync(
    //port to serve on
    "0.0.0.0:9001",
    //authentication settings
    grpc.ServerCredentials.createInsecure(),
    //server start callback 
    (error, port) => {
      console.log(`listening on port ${port}`);
      server.start();
    }
  );