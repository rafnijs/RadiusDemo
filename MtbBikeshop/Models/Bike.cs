using System.ComponentModel.DataAnnotations;

namespace MtbBikeshop.Models;

public class Bike
{
    public int Id { get; set; }

    public int Rank { get; set; }

    [Required, MaxLength(100)]
    public string Brand { get; set; } = string.Empty;

    [Required, MaxLength(150)]
    public string Model { get; set; } = string.Empty;

    [MaxLength(50)]
    public string Category { get; set; } = string.Empty;

    public int ModelYear { get; set; }

    [MaxLength(50)]
    public string FrameMaterial { get; set; } = string.Empty;

    [MaxLength(30)]
    public string WheelSize { get; set; } = string.Empty;

    public int FrontTravelMm { get; set; }

    public int RearTravelMm { get; set; }

    public double WeightKg { get; set; }

    public decimal Price { get; set; }

    public int Stock { get; set; }

    [MaxLength(1000)]
    public string Description { get; set; } = string.Empty;

    public List<BikePart> Parts { get; set; } = [];

    public string FullName => $"{Brand} {Model}";
}
