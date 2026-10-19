# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src

COPY ["PetClinic.Core/PetClinic.Core.csproj", "PetClinic.Core/"]
COPY ["PetClinic.Infrastructure/PetClinic.Infrastructure.csproj", "PetClinic.Infrastructure/"]
COPY ["PetClinic.Web/PetClinic.Web.csproj", "PetClinic.Web/"]

# If you have a solution file at the repository root, uncomment this:
COPY ["PetClinic.sln", "./"]

# Restore dependency graph beginning at the executable web project.
RUN dotnet restore "PetClinic.Web/PetClinic.Web.csproj"

# Copy remaining source files and publish the web application.
COPY . .
RUN dotnet publish "PetClinic.Web/PetClinic.Web.csproj" \
    --configuration Release \
    --output /app/publish \
    /p:UseAppHost=false
COPY elastic_apm_profiler /app/publish/elastic_apm_profiler
COPY elastic_apm_agent /app/publish/elastic_apm_agent

# ---- Runtime stage ----
FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final
WORKDIR /app

# .NET 8 container defaults commonly use port 8080.
# In this example, we are using Elastic APM 
ENV ELASTIC_APM_SERVER_URL=http://localhost:8080
ENV ELASTIC_APM_API_KEY=missing-key
ENV ELASTIC_APM_ENVIRONMENT=development
ENV ELASTIC_APM_SERVICE_NAME=dotnet-petclinic2
ENV DOTNET_STARTUP_HOOKS=/app/elastic_apm_agent/ElasticApmAgentStartupHook.dll

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Only published output is included in the runtime image.
COPY --from=build /app/publish .

ENTRYPOINT ["dotnet", "PetClinic.Web.dll"]
