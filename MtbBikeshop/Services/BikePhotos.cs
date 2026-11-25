using MtbBikeshop.Models;

namespace MtbBikeshop.Services;

public sealed record BikePhoto(string? ImageUrl, string SourceUrl, string Description);

public static class BikePhotos
{
    public static BikePhoto? For(Bike bike) => bike.FullName switch
    {
        "Santa Cruz Megatower CC X0 AXS" => new(
            "https://www.santacruzbicycles.com/cdn/shop/files/Canazei24_K4A4971.jpg?v=1737522692&width=1200",
            "https://www.santacruzbicycles.com/products/megatower-x-0-axs-2025",
            "Santa Cruz Megatower. Manufacturer model photo; exact build and model year are not confirmed."),
        "Specialized Stumpjumper 15 Expert" => new(
            "https://resources.specialized.com/media-libraries/mleF1gIlpsGs/images/containers/3DKuwhuDwkqnh5RM9SztGhkGZk5/93325-31_SJ-15-EXPERT-GUN-WHTMTN_HERO-PDP.webp",
            "https://www.specialized.com/us/en/stumpjumper-15-expert-sram-gx-axs-fox-performance-elite/p/4221401",
            "Specialized Stumpjumper 15 Expert, Gunmetal / White Mountains. Manufacturer photo; model year may differ from the catalog."),
        "Trek Fuel EX 9.8 GX AXS Gen 6" => new(
            null,
            "https://www.trekbikes.com/us/en_US/bikes/mountain-bikes/trail-mountain-bikes/all-mountain-bikes/fuel/fuel-ex/fuel-ex-9-8-gx-axs-gen-6/p/36953/",
            "Trek Fuel EX 9.8 GX AXS Gen 6. View the exact model and its photos on Trek's website."),
        "Yeti SB140 C2 Lunch Ride" => new(
            "https://yeticycles-prod.zaneray.com/cms/images/aNGHdJ5xUNkB0_CZ_SB140BikePageHeroMobile.jpg",
            "https://yeticycles.com/en-us/bikes/sb140",
            "Yeti SB140. Manufacturer model photo; the C2 Lunch Ride build and model year are not confirmed."),
        "Ibis Ripmo V3 XT" => new(
            "https://ibiscycles.imgix.net/images/Bikes/Ripmo-V3/Builder-MY26/ripmo-v3-my26-olive-xtdi2.jpg?fit=max&q=100&w=2400&s=6db2fa41298ba2e446941b3b335ea285",
            "https://www.ibiscycles.com/bikes/ripmo",
            "Ibis Ripmo V3, MY2026, Olive, XT Di2 build. The photo shows XT Di2 rather than the catalog's mechanical XT build."),
        "Transition Spire Carbon X0 AXS" => new(
            "https://www.transitionbikes.com/images/C1-Spire-Carbon-E90-B.avif",
            "https://www.transitionbikes.com/Bikes/Spire",
            "Transition Spire Carbon, Ultraviolet, Eagle 90 build. The photo shows Eagle 90 rather than the catalog's X0 AXS build; model year may differ."),
        "Pivot Switchblade Pro X0 AXS" => new(
            "https://cdn.shopify.com/s/files/1/0576/7954/4474/files/00SWBV629AXOB--BLNLGDRPCN.png?v=1767047514",
            "https://www.pivotcycles.com/en-us/products/switchblade-pro-x0-eagle-transmission",
            "Pivot Switchblade Pro X0 Eagle Transmission. The manufacturer's pictured build is named Eagle Transmission rather than the catalog's X0 AXS; model year may differ."),
        "Canyon Spectral CF 8" => new(
            "https://dma.canyon.com/image/upload/w_1439,c_fit/b_rgb:F2F2F2/f_auto/q_auto/v1787554502/2027_FULL_spectral_cf-8_4381_M179_P08_P5_29_pnjmnh",
            "https://www.canyon.com/en-us/mountain-bikes/trail-bikes/spectral/cf/spectral-cf-8/4381.html",
            "Canyon Spectral CF 8. Manufacturer MY2027 image, rather than the catalog's MY2026."),
        "Specialized Epic 8 Pro" => new(
            "https://resources.specialized.com/media-libraries/mleF1gIlpsGs/images/containers/3DKr1MwSKwp9e6E6IaZ46MFq4zS/90325-12_EPIC-8-PRO-LGNBLUTNT-LQDMET-YEL_HERO-PDP.webp",
            "https://www.specialized.com/us/en/epic-8-pro-sram-x0-axs-rockshox-ultimate/p/4221503",
            "Specialized Epic 8 Pro, Legion Blue Tint / Liquid Metal Yellow. Manufacturer photo; model year may differ from the catalog."),
        "Orbea Occam LT M10" => new(
            null,
            "https://www.orbea.com/en-us/occam-lt-m10",
            "Orbea Occam LT M10. View the exact model and its photos in Orbea's configurator."),
        _ => null
    };
}
