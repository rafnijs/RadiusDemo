using System.ComponentModel.DataAnnotations;

namespace MtbBikeshop.Models;

public class Order
{
    public int Id { get; set; }

    public DateTime CreatedUtc { get; set; } = DateTime.UtcNow;

    [Required, MaxLength(100)]
    public string CustomerName { get; set; } = string.Empty;

    [Required, EmailAddress, MaxLength(200)]
    public string Email { get; set; } = string.Empty;

    [Required, MaxLength(300)]
    public string Address { get; set; } = string.Empty;

    public decimal Total { get; set; }

    public List<OrderItem> Items { get; set; } = [];
}

public class OrderItem
{
    public int Id { get; set; }

    public int OrderId { get; set; }
    public Order? Order { get; set; }

    public int BikeId { get; set; }
    public Bike? Bike { get; set; }

    [MaxLength(250)]
    public string BikeName { get; set; } = string.Empty;

    public int Quantity { get; set; }

    public decimal UnitPrice { get; set; }
}
