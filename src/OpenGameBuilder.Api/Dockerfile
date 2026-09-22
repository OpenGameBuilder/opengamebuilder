FROM mcr.microsoft.com/dotnet/sdk:10.0.401@sha256:35d40304542c8689331f8cab17c65926cdf48fe711e289321d71924b230a7d29 AS build
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

FROM mcr.microsoft.com/dotnet/aspnet:10.0.12@sha256:2d584d8147faddb0d678c5748d47953e5b8e18621ed4fb7049a91381d9d7746f AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

USER $APP_UID

ENTRYPOINT ["dotnet", "OpenGameBuilder.Api.dll"]
