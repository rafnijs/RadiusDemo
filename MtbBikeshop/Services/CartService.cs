using System.Text.Json;

namespace MtbBikeshop.Services;

public record CartLine(int BikeId, string Name, decimal UnitPrice, int Quantity)
{
    public decimal LineTotal => UnitPrice * Quantity;
}

public class CartService(IHttpContextAccessor httpContextAccessor)
{
    private const string SessionKey = "Cart";

    private ISession Session => httpContextAccessor.HttpContext?.Session
        ?? throw new InvalidOperationException("No active HTTP session.");

    public List<CartLine> GetLines()
    {
        var json = Session.GetString(SessionKey);
        return string.IsNullOrEmpty(json)
            ? []
            : JsonSerializer.Deserialize<List<CartLine>>(json) ?? [];
    }

    public int Count => GetLines().Sum(l => l.Quantity);

    public decimal Total => GetLines().Sum(l => l.LineTotal);

    public void Add(int bikeId, string name, decimal unitPrice, int quantity = 1)
    {
        var lines = GetLines();
        var existing = lines.FindIndex(l => l.BikeId == bikeId);
        if (existing >= 0)
        {
            lines[existing] = lines[existing] with { Quantity = lines[existing].Quantity + quantity };
        }
        else
        {
            lines.Add(new CartLine(bikeId, name, unitPrice, quantity));
        }
        Save(lines);
    }

    public void Remove(int bikeId)
    {
        var lines = GetLines();
        lines.RemoveAll(l => l.BikeId == bikeId);
        Save(lines);
    }

    public void Clear() => Session.Remove(SessionKey);

    private void Save(List<CartLine> lines) =>
        Session.SetString(SessionKey, JsonSerializer.Serialize(lines));
}
