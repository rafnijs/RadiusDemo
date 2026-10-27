using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Models;
using MtbBikeshop.Services;

namespace MtbBikeshop.Pages.Bikes;

public class DetailsModel(ShopDbContext db, CartService cart) : PageModel
{
    public Bike Bike { get; private set; } = default!;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var bike = await db.Bikes.AsNoTracking()
            .Include(b => b.Parts.OrderBy(p => p.SortOrder))
            .FirstOrDefaultAsync(b => b.Id == id);
        if (bike is null)
        {
            return NotFound();
        }
        Bike = bike;
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(int id, int quantity = 1)
    {
        var bike = await db.Bikes.FindAsync(id);
        if (bike is null)
        {
            return NotFound();
        }
        cart.Add(bike.Id, bike.FullName, bike.Price, Math.Clamp(quantity, 1, 10));
        return RedirectToPage("/Cart");
    }
}
