# Build context is ./backend (see docker-compose.yml).

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY global.json ./
COPY src/Fleet.Simulator/Fleet.Simulator.csproj src/Fleet.Simulator/
RUN dotnet restore src/Fleet.Simulator/Fleet.Simulator.csproj

COPY src/Fleet.Simulator/ src/Fleet.Simulator/
RUN dotnet publish src/Fleet.Simulator/Fleet.Simulator.csproj -c Release -o /app/publish --no-restore

# A console app needs only the .NET runtime, not ASP.NET Core.
FROM mcr.microsoft.com/dotnet/runtime:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Fleet.Simulator.dll"]
