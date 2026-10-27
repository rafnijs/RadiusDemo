using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Models;
using MtbBikeshop.Services;

namespace MtbBikeshop.Pages;

public class IndexModel(ShopDbContext db, CartService cart) : PageModel
{
    public List<Bike> Bikes { get; private set; } = [];
    public List<string> Categories { get; private set; } = [];

    [BindProperty(SupportsGet = true)]
    public string? Category { get; set; }

    public async Task OnGetAsync()
    {
        Categories = await db.Bikes.Select(b => b.Category).Distinct().OrderBy(c => c).ToListAsync();

        var query = db.Bikes.AsNoTracking();
        if (!string.IsNullOrWhiteSpace(Category))
        {
            query = query.Where(b => b.Category == Category);
        }
        Bikes = await query.OrderBy(b => b.Rank).ToListAsync();
    }

    public async Task<IActionResult> OnPostAddToCartAsync(int id)
    {
        var bike = await db.Bikes.FindAsync(id);
        if (bike is null)
        {
            return NotFound();
        }
        cart.Add(bike.Id, bike.FullName, bike.Price);
        TempData["Message"] = $"{bike.FullName} added to your cart.";
        return RedirectToPage(new { Category });
    }
}
