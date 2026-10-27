using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using MtbBikeshop.Services;

namespace MtbBikeshop.Pages;

public class CartModel(CartService cart) : PageModel
{
    public List<CartLine> Lines { get; private set; } = [];
    public decimal Total { get; private set; }

    public void OnGet()
    {
        Lines = cart.GetLines();
        Total = Lines.Sum(l => l.LineTotal);
    }

    public IActionResult OnPostRemove(int id)
    {
        cart.Remove(id);
        return RedirectToPage();
    }
}
