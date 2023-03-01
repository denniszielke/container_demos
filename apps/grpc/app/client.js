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
  const UserService = grpc.loadPackageDefinition(pkgDefs).UserService;
  
  //create the Client
  const client = new UserService(
    "127.0.0.1:9001",
    grpc.credentials.createInsecure()
  );
  
  //make a call to GetUser
  client.GetUser({}, (error, user) => {
    if (error) {
      console.log(error);
    } else {
      console.log(user);
    }
  });