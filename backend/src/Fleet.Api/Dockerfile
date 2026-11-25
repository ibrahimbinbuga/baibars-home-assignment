# Build context is ./backend (see docker-compose.yml), so paths are relative to that folder.

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restore first, using only project files, so the restore layer is cached until dependencies change.
COPY global.json ./
COPY src/Fleet.Api/Fleet.Api.csproj src/Fleet.Api/
RUN dotnet restore src/Fleet.Api/Fleet.Api.csproj

COPY src/Fleet.Api/ src/Fleet.Api/
RUN dotnet publish src/Fleet.Api/Fleet.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
COPY --from=build /app/publish .
# The aspnet image listens on 8080 and runs as the non-root "app" user by default.
EXPOSE 8080
ENTRYPOINT ["dotnet", "Fleet.Api.dll"]
