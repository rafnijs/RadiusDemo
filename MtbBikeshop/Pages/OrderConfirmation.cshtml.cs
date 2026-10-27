using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Models;

namespace MtbBikeshop.Pages;

public class OrderConfirmationModel(ShopDbContext db) : PageModel
{
    public Order Order { get; private set; } = default!;

    public async Task<IActionResult> OnGetAsync(int id)
    {
        var order = await db.Orders.AsNoTracking()
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == id);
        if (order is null)
        {
            return NotFound();
        }
        Order = order;
        return Page();
    }
}
