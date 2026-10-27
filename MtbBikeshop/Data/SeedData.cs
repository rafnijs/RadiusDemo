using Microsoft.EntityFrameworkCore;
using MtbBikeshop.Models;

namespace MtbBikeshop.Data;

public static class SeedData
{
    public static async Task InitializeAsync(ShopDbContext db)
    {
        await db.Database.EnsureCreatedAsync();

        if (await db.Bikes.AnyAsync())
        {
            return;
        }

        db.Bikes.AddRange(GetTopTenBikes());
        await db.SaveChangesAsync();
    }

    private static Bike CreateBike(
        int rank, string brand, string model, string category, string frame, string wheels,
        int front, int rear, double weight, decimal price, int stock, string description,
        params (string Component, string Name)[] parts) => new()
    {
        Rank = rank,
        Brand = brand,
        Model = model,
        Category = category,
        ModelYear = 2026,
        FrameMaterial = frame,
        WheelSize = wheels,
        FrontTravelMm = front,
        RearTravelMm = rear,
        WeightKg = weight,
        Price = price,
        Stock = stock,
        Description = description,
        Parts = parts.Select((p, i) => new BikePart { Component = p.Component, Name = p.Name, SortOrder = i }).ToList()
    };

    public static IEnumerable<Bike> GetTopTenBikes() =>
    [
        CreateBike(1, "Santa Cruz", "Megatower CC X0 AXS", "Enduro", "Carbon CC", "29\"", 170, 165, 15.4, 9999m, 4,
            "The benchmark long-travel 29er. Lower-link VPP suspension and adjustable progression make it a race-ready enduro sled that still climbs well.",
            ("Frame", "Megatower Carbon CC, 165 mm VPP"),
            ("Fork", "RockShox ZEB Ultimate, 170 mm"),
            ("Rear shock", "RockShox Vivid Ultimate Air"),
            ("Drivetrain", "SRAM X0 Eagle Transmission AXS, 1x12"),
            ("Brakes", "SRAM Maven Silver, 4-piston"),
            ("Wheels", "Reserve 30|HD Carbon, DT Swiss 350 hubs"),
            ("Tyres", "Maxxis Assegai 2.5 / Minion DHR II 2.4"),
            ("Dropper post", "RockShox Reverb AXS"),
            ("Cockpit", "Santa Cruz carbon 800 mm bar, Burgtec stem"),
            ("Saddle", "WTB Silverado")),

        CreateBike(2, "Specialized", "Stumpjumper 15 Expert", "Trail", "FACT 11m Carbon", "29\"", 160, 145, 14.5, 7499m, 6,
            "The do-it-all trail bike. Genie air-shock technology gives a supple top stroke and big-hit support, with SWAT frame storage.",
            ("Frame", "Stumpjumper 15 FACT 11m Carbon, 145 mm"),
            ("Fork", "Fox 36 Performance Elite, 160 mm"),
            ("Rear shock", "Fox Float X Genie Performance Elite"),
            ("Drivetrain", "SRAM GX Eagle Transmission AXS, 1x12"),
            ("Brakes", "SRAM Maven Bronze, 4-piston"),
            ("Wheels", "Roval Traverse Alloy 30 mm"),
            ("Tyres", "Specialized Butcher / Eliminator Grid Trail 2.3"),
            ("Dropper post", "X-Fusion Manic"),
            ("Cockpit", "Specialized Trail alloy 800 mm bar, Trail stem"),
            ("Saddle", "Specialized Bridge Comp")),

        CreateBike(3, "Trek", "Fuel EX 9.8 GX AXS Gen 6", "Trail", "OCLV Mountain Carbon", "29\"", 150, 140, 14.6, 6999m, 8,
            "Adjustable geometry, Mino Link and in-frame storage make the Fuel EX one of the most versatile trail bikes on the market.",
            ("Frame", "Fuel EX OCLV Mountain Carbon, 140 mm ABP"),
            ("Fork", "Fox 36 Rhythm GRIP, 150 mm"),
            ("Rear shock", "Fox Float X Performance"),
            ("Drivetrain", "SRAM GX Eagle Transmission AXS, 1x12"),
            ("Brakes", "SRAM DB8, 4-piston"),
            ("Wheels", "Bontrager Line Comp 30, alloy"),
            ("Tyres", "Bontrager SE5 / XR5 Team Issue 2.5"),
            ("Dropper post", "Bontrager Line Dropper"),
            ("Cockpit", "Bontrager Line Pro carbon bar, RSL stem"),
            ("Saddle", "Bontrager Arvada")),

        CreateBike(4, "Yeti", "SB140 C2 Lunch Ride", "Trail", "Carbon C-Series", "29\"", 160, 140, 14.3, 7990m, 3,
            "Switch Infinity suspension delivers efficient pedalling and a playful, poppy ride. The Lunch Ride build adds bigger fork and tyres.",
            ("Frame", "SB140 C-Series Carbon, Switch Infinity 140 mm"),
            ("Fork", "Fox 36 Performance, 160 mm"),
            ("Rear shock", "Fox Float X Performance"),
            ("Drivetrain", "SRAM GX Eagle, 1x12"),
            ("Brakes", "SRAM Code R, 4-piston"),
            ("Wheels", "DT Swiss M1900, 30 mm"),
            ("Tyres", "Maxxis Minion DHF 2.5 / DHR II 2.4"),
            ("Dropper post", "Fox Transfer Performance"),
            ("Cockpit", "Yeti carbon bar, Burgtec Enduro MK3 stem"),
            ("Saddle", "WTB Silverado")),

        CreateBike(5, "Ibis", "Ripmo V3 XT", "All-Mountain", "Carbon", "29\"", 160, 150, 14.2, 7299m, 5,
            "DW-Link suspension, short offset fork and generous tyre clearance. A lively all-mountain bike that feels at home everywhere.",
            ("Frame", "Ripmo Carbon, DW-Link 150 mm"),
            ("Fork", "Fox 36 Performance, 160 mm"),
            ("Rear shock", "Fox Float X Performance"),
            ("Drivetrain", "Shimano Deore XT M8100, 1x12"),
            ("Brakes", "Shimano Deore XT M8120, 4-piston"),
            ("Wheels", "Ibis S35 Alloy, Ibis hubs"),
            ("Tyres", "Maxxis Assegai 2.5 / Dissector 2.4"),
            ("Dropper post", "Bike Yoke Revive 2.0"),
            ("Cockpit", "Ibis Hi-Fi carbon bar, Ibis stem"),
            ("Saddle", "Ibis by WTB")),

        CreateBike(6, "Transition", "Spire Carbon X0 AXS", "Enduro", "Carbon", "29\"", 170, 170, 15.9, 8999m, 2,
            "Speed Balanced Geometry and GiddyUp suspension make the Spire a confident, stable bike for steep, fast and technical terrain.",
            ("Frame", "Spire Carbon, GiddyUp 170 mm"),
            ("Fork", "Fox 38 Factory GRIP2, 170 mm"),
            ("Rear shock", "Fox Float X2 Factory"),
            ("Drivetrain", "SRAM X0 Eagle Transmission AXS, 1x12"),
            ("Brakes", "SRAM Code Silver Stealth, 4-piston"),
            ("Wheels", "DT Swiss EX1700 / 350 hubs"),
            ("Tyres", "Maxxis Assegai EXO+ 2.5 / DHR II DD 2.4"),
            ("Dropper post", "OneUp V3 Dropper"),
            ("Cockpit", "ANVL Mandrel stem, Transition alloy bar"),
            ("Saddle", "ANVL Forge")),

        CreateBike(7, "Pivot", "Switchblade Pro X0 AXS", "Trail", "Hollow-core Carbon", "29\"", 160, 142, 13.9, 9499m, 3,
            "DW-Link efficiency with a playful, precise trail feel. Super Boost Plus rear end makes for exceptionally stiff, strong wheels.",
            ("Frame", "Switchblade Carbon, DW-Link 142 mm"),
            ("Fork", "Fox 36 Factory GRIP X2, 160 mm"),
            ("Rear shock", "Fox Float X Factory"),
            ("Drivetrain", "SRAM X0 Eagle Transmission AXS, 1x12"),
            ("Brakes", "Shimano XT 4-piston"),
            ("Wheels", "DT Swiss XM1700, 30 mm"),
            ("Tyres", "Maxxis Minion DHF 2.5 / Dissector 2.4"),
            ("Dropper post", "Fox Transfer Factory"),
            ("Cockpit", "Phoenix Team Trail/Enduro carbon bar, Phoenix stem"),
            ("Saddle", "Phoenix WTB Vino")),

        CreateBike(8, "Canyon", "Spectral CF 8", "Trail", "Carbon CF", "29\"", 150, 140, 14.6, 4299m, 12,
            "Outstanding value: a carbon trail bike with a premium spec, progressive geometry and a lively four-bar suspension platform.",
            ("Frame", "Spectral CF Carbon, 140 mm four-bar"),
            ("Fork", "Fox 36 Rhythm GRIP, 150 mm"),
            ("Rear shock", "Fox Float X Performance"),
            ("Drivetrain", "Shimano Deore XT / SLX, 1x12"),
            ("Brakes", "Shimano SLX M7120, 4-piston"),
            ("Wheels", "DT Swiss M1900 Spline"),
            ("Tyres", "Maxxis Minion DHF 2.5 / DHR II 2.4"),
            ("Dropper post", "Canyon Iridium Dropper"),
            ("Cockpit", "Canyon G5 alloy bar and stem"),
            ("Saddle", "Ergon SM Enduro")),

        CreateBike(9, "Specialized", "Epic 8 Pro", "Cross-Country", "FACT 11m Carbon", "29\"", 120, 120, 10.6, 8499m, 4,
            "World Cup-winning XC race bike with a modern, capable geometry. Light, fast and efficient on every climb.",
            ("Frame", "Epic 8 FACT 11m Carbon, 120 mm"),
            ("Fork", "RockShox SID Ultimate, 120 mm"),
            ("Rear shock", "RockShox SIDLuxe Ultimate"),
            ("Drivetrain", "SRAM X0 Eagle Transmission AXS, 1x12"),
            ("Brakes", "SRAM Level Silver Stealth, 2-piston"),
            ("Wheels", "Roval Control Carbon, 29 mm"),
            ("Tyres", "Specialized Fast Trak / Renegade Control 2.35"),
            ("Dropper post", "RockShox Reverb AXS"),
            ("Cockpit", "Roval Control Carbon bar, Specialized stem"),
            ("Saddle", "Specialized Power Pro")),

        CreateBike(10, "Orbea", "Occam LT M10", "Trail", "OMR Carbon", "29\"", 160, 150, 14.2, 6499m, 7,
            "A long-travel version of Orbea's trail favourite with Lockr tool storage and the MyO custom paint programme.",
            ("Frame", "Occam LT OMR Carbon, 150 mm"),
            ("Fork", "Fox 36 Float Performance Elite, 160 mm"),
            ("Rear shock", "Fox Float X Performance Elite"),
            ("Drivetrain", "Shimano Deore XT M8100, 1x12"),
            ("Brakes", "Shimano Deore XT M8120, 4-piston"),
            ("Wheels", "Oquo Mountain Control MC32 Team carbon"),
            ("Tyres", "Maxxis Assegai 2.5 / DHR II 2.4"),
            ("Dropper post", "OC Mountain Control MC21"),
            ("Cockpit", "OC Mountain Control MC10 bar and stem"),
            ("Saddle", "Fizik Terra Alpaca X5"))
    ];
}
