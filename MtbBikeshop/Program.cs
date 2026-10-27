using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Data;
using MtbBikeshop.Services;

var builder = WebApplication.CreateBuilder(args);

var shopDbConnectionString = builder.Configuration.GetConnectionString("ShopDb")
    ?? throw new InvalidOperationException(
        "Connection string 'ShopDb' is required. Set ConnectionStrings__ShopDb.");

builder.Services.AddRazorPages();
builder.Services.AddDbContext<ShopDbContext>(options =>
    options.UseSqlServer(shopDbConnectionString));
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromHours(2);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});
builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<CartService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ShopDbContext>();
    await SeedData.InitializeAsync(db);
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseSession();

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

app.Run();
