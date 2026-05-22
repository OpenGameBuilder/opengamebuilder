FROM mcr.microsoft.com/dotnet/sdk:10.0.300 AS build
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
    --output /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app

COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "OpenGameBuilder.Api.dll"]
