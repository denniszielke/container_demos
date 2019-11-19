# DAPR - Actors

https://github.com/dapr/dotnet-sdk/blob/master/docs/get-started-dapr-actor.md
dotnet new sln -o dapr-actors

dotnet new classlib -o MyActor.Interfaces
cd MyActor.Interfaces

dotnet add package Dapr.Actors

# Setup remote state store
https://github.com/dapr/docs/tree/master/howto/setup-state-store