using System.ComponentModel.DataAnnotations;

namespace MtbBikeshop.Models;

public class BikePart
{
    public int Id { get; set; }

    public int BikeId { get; set; }
    public Bike? Bike { get; set; }

    [Required, MaxLength(50)]
    public string Component { get; set; } = string.Empty;

    [Required, MaxLength(200)]
    public string Name { get; set; } = string.Empty;

    public int SortOrder { get; set; }
}
