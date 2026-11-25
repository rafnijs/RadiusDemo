#:package Microsoft.Data.SqlClient@6.1.7
using Microsoft.Data.SqlClient;

string Required(string name) =>
    Environment.GetEnvironmentVariable(name) is { Length: > 0 } value
        ? value
        : throw new InvalidOperationException($"{name} is not set.");

var clientId = Guid.Parse(Required("IDENTITY_CLIENT_ID"));
var builder = new SqlConnectionStringBuilder
{
    DataSource = $"tcp:{Required("SQL_SERVER")},1433",
    InitialCatalog = Required("SQL_DATABASE"),
    Encrypt = SqlConnectionEncryptOption.Mandatory,
    TrustServerCertificate = false,
};

var sql = File.ReadAllText("/sql/grant-app-access.sql")
    .Replace("$(IdentityClientId)", clientId.ToString());

using var connection = new SqlConnection(builder.ConnectionString)
{
    AccessToken = File.ReadAllText("/token/accessToken").Trim(),
};
connection.Open();
using (var command = new SqlCommand(sql, connection))
{
    command.ExecuteNonQuery();
}

using var verify = new SqlCommand(
    "SELECT CONVERT(varchar(34), u.sid, 1), u.type_desc, " +
    "CONVERT(varchar(34), CONVERT(binary(16), @clientId), 1) " +
    "FROM sys.database_principals u WHERE u.name = N'mtbbikeshop';", connection);
verify.Parameters.AddWithValue("@clientId", clientId);
using var reader = verify.ExecuteReader();
if (!reader.Read())
{
    throw new InvalidOperationException("The mtbbikeshop database principal was not found.");
}
Console.WriteLine($"Database user SID: {reader.GetString(0)}");
Console.WriteLine($"Database user type: {reader.GetString(1)}");
Console.WriteLine($"Expected SID from managed identity client ID: {reader.GetString(2)}");
if (!string.Equals(reader.GetString(0), reader.GetString(2), StringComparison.OrdinalIgnoreCase))
{
    throw new InvalidOperationException("The database user SID does not match the managed identity client ID.");
}
