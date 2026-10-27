using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Models;

namespace MtbBikeshop.Pages;

public class PartsListModel(ShopDbContext db) : PageModel
{
    public List<Bike> Bikes { get; private set; } = [];
    public List<string> Components { get; private set; } = [];

    public async Task OnGetAsync()
    {
        Bikes = await db.Bikes.AsNoTracking()
            .Include(b => b.Parts)
            .OrderBy(b => b.Rank)
            .ToListAsync();

        Components = Bikes.SelectMany(b => b.Parts)
            .GroupBy(p => p.Component)
            .OrderBy(g => g.Min(p => p.SortOrder))
            .Select(g => g.Key)
            .ToList();
    }

    public string PartFor(Bike bike, string component) =>
        bike.Parts.FirstOrDefault(p => p.Component == component)?.Name ?? "—";
}
