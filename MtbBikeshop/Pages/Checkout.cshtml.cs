using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Models;
using MtbBikeshop.Services;

namespace MtbBikeshop.Pages;

public class CheckoutModel(ShopDbContext db, CartService cart) : PageModel
{
    public List<CartLine> Lines { get; private set; } = [];
    public decimal Total { get; private set; }

    [BindProperty]
    public CheckoutInput Input { get; set; } = new();

    public class CheckoutInput
    {
        [Required, MaxLength(100), Display(Name = "Full name")]
        public string CustomerName { get; set; } = string.Empty;

        [Required, EmailAddress, MaxLength(200)]
        public string Email { get; set; } = string.Empty;

        [Required, MaxLength(300), Display(Name = "Delivery address")]
        public string Address { get; set; } = string.Empty;
    }

    public IActionResult OnGet()
    {
        LoadCart();
        return Lines.Count == 0 ? RedirectToPage("/Cart") : Page();
    }

    public async Task<IActionResult> OnPostAsync()
    {
        LoadCart();
        if (Lines.Count == 0)
        {
            return RedirectToPage("/Cart");
        }
        if (!ModelState.IsValid)
        {
            return Page();
        }

        var ids = Lines.Select(l => l.BikeId).ToList();
        var bikes = await db.Bikes.Where(b => ids.Contains(b.Id)).ToDictionaryAsync(b => b.Id);

        var order = new Order
        {
            CustomerName = Input.CustomerName,
            Email = Input.Email,
            Address = Input.Address
        };

        foreach (var line in Lines)
        {
            if (!bikes.TryGetValue(line.BikeId, out var bike) || bike.Stock < line.Quantity)
            {
                ModelState.AddModelError(string.Empty, $"Not enough stock for {line.Name}.");
                return Page();
            }
            bike.Stock -= line.Quantity;
            order.Items.Add(new OrderItem
            {
                BikeId = bike.Id,
                BikeName = bike.FullName,
                Quantity = line.Quantity,
                UnitPrice = bike.Price
            });
        }
        order.Total = order.Items.Sum(i => i.UnitPrice * i.Quantity);

        db.Orders.Add(order);
        await db.SaveChangesAsync();
        cart.Clear();

        return RedirectToPage("/OrderConfirmation", new { id = order.Id });
    }

    private void LoadCart()
    {
        Lines = cart.GetLines();
        Total = Lines.Sum(l => l.LineTotal);
    }
}
