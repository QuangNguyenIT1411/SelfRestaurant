FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

COPY SelfRestaurant.Microservices.sln ./
COPY src/Gateway/SelfRestaurant.Gateway.Mvc/SelfRestaurant.Gateway.Mvc.csproj src/Gateway/SelfRestaurant.Gateway.Mvc/

RUN dotnet restore src/Gateway/SelfRestaurant.Gateway.Mvc/SelfRestaurant.Gateway.Mvc.csproj

COPY src/ ./src/

RUN dotnet publish src/Gateway/SelfRestaurant.Gateway.Mvc/SelfRestaurant.Gateway.Mvc.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:8.0
WORKDIR /app
COPY --from=build /app/publish/ ./
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "SelfRestaurant.Gateway.Mvc.dll"]
