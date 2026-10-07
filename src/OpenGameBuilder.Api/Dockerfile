FROM mcr.microsoft.com/dotnet/sdk:10.0.401@sha256:e70cdb7f80b0348f5cb85f19a8f670fca061f033d57eed12fa003d58b0e06317 AS build
WORKDIR /repo

COPY global.json .
COPY NuGet.Config .
COPY Directory.Build.props .
COPY Directory.Build.targets .
COPY Directory.Packages.props .
COPY opengamebuilder.slnx .

COPY src/ ./src/

RUN dotnet publish src/OpenGameBuilder.Api/OpenGameBuilder.Api.csproj \
    --configuration Release \
    -p:RestoreLockedMode=true \
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0.12@sha256:222759b391a1aaf241166672c8f99b2d4ada452e7b5319f3c6e8f265a37b5ad4 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

USER $APP_UID

ENTRYPOINT ["dotnet", "OpenGameBuilder.Api.dll"]
