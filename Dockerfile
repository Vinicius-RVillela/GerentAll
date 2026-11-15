# Build da API (o app desktop Avalonia não roda em container)
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Restaura primeiro só com os .csproj para aproveitar o cache das camadas
COPY src/Mercadinho.Domain/Mercadinho.Domain.csproj src/Mercadinho.Domain/
COPY src/Mercadinho.Application/Mercadinho.Application.csproj src/Mercadinho.Application/
COPY src/Mercadinho.Infrastructure/Mercadinho.Infrastructure.csproj src/Mercadinho.Infrastructure/
COPY src/Mercadinho.Api/Mercadinho.Api.csproj src/Mercadinho.Api/
RUN dotnet restore src/Mercadinho.Api/Mercadinho.Api.csproj

COPY src/ src/
RUN dotnet publish src/Mercadinho.Api/Mercadinho.Api.csproj -c Release -o /app --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
# Usuário sem privilégios já incluso na imagem oficial
USER app
ENTRYPOINT ["dotnet", "Mercadinho.Api.dll"]
