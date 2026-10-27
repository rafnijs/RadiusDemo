using System.Globalization;

namespace MtbBikeshop.Services;

public static class Format
{
    private static readonly CultureInfo Euro = CultureInfo.GetCultureInfo("nl-BE");

    public static string Money(decimal amount) => amount.ToString("C0", Euro);
}
