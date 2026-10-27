FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY MtbBikeshop.csproj ./
RUN dotnet restore MtbBikeshop.csproj
COPY . ./
RUN dotnet publish MtbBikeshop.csproj -c Release -o /app/publish --no-restore /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
RUN mkdir -p /app/data && chown app:app /app/data
COPY --from=build /app/publish ./
ENV ASPNETCORE_HTTP_PORTS=8080 \
    ConnectionStrings__ShopDb="Data Source=/app/data/mtbbikeshop.db"
EXPOSE 8080
USER app
ENTRYPOINT ["dotnet", "MtbBikeshop.dll"]
