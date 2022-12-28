/**
 * Include file for chat colors
 *
 * Original plugin website: https://github.com/Ciallo-Ani/mytimer/tree/gokz-framework
 */

#if defined _shavit_colors_included_
#endinput
#endif
#define _shavit_colors_included_



char gS_GlobalColorNames[][] =
{
	"{default}", // default color in CS:S is yellow
	"{team}"
};

char gS_GlobalColors[][] =
{
	"\x01",
	"\x03"
};

// Custom colors from multicolors
char gS_CustomColorNames[][] =
{
	"{aliceblue}", 
	"{allies}", 
	"{ancient}", 
	"{antiquewhite}", 
	"{aqua}", 
	"{aquamarine}", 
	"{arcana}", 
	"{axis}", 
	"{azure}", 

	"{beige}", 
	"{bisque}", 
	"{black}", 
	"{blanchedalmond}", 
	"{blue}", 
	"{blueviolet}", 
	"{brown}", 
	"{burlywood}", 

	"{cadetblue}", 
	"{chartreuse}", 
	"{chocolate}", 
	"{collectors}", 
	"{common}", 
	"{community}", 
	"{coral}", 
	"{cornflowerblue}", 
	"{cornsilk}", 
	"{corrupted}", 
	"{crimson}", 
	"{cyan}", 

	"{darkblue}", 
	"{darkcyan}", 
	"{darkgoldenrod}", 
	"{darkgray}", 
	"{darkgrey}", 
	"{darkgreen}", 
	"{darkkhaki}", 
	"{darkmagenta}", 
	"{darkolivegreen}", 
	"{darkorange}", 
	"{darkorchid}", 
	"{darkred}", 
	"{darksalmon}", 
	"{darkseagreen}", 
	"{darkslateblue}", 
	"{darkslategray}", 
	"{darkslategrey}", 
	"{darkturquoise}", 
	"{darkviolet}", 
	"{deeppink}", 
	"{deepskyblue}", 
	"{dimgray}", 
	"{dimgrey}", 
	"{dodgerblue}", 

	"{exalted}", 

	"{firebrick}", 
	"{floralwhite}", 
	"{forestgreen}", 
	"{frozen}", 
	"{fuchsia}", 
	"{fullblue}", 
	"{fullred}", 

	"{gainsboro}", 
	"{genuine}", 
	"{ghostwhite}", 
	"{gold}", 
	"{goldenrod}", 
	"{gray}", 
	"{grey}", 
	"{greenyellow}", 

	"{haunted}", 
	"{honeydew}", 
	"{hotpink}", 

	"{immortal}", 
	"{indianred}", 
	"{indigo}", 
	"{ivory}", 

	"{khaki}", 

	"{lavender}", 
	"{lavenderblush}", 
	"{lawngreen}", 
	"{legendary}", 
	"{lemonchiffon}", 
	"{lightblue}", 
	"{lightcoral}", 
	"{lightcyan}", 
	"{lightgoldenrodyellow}", 
	"{lightgray}", 
	"{lightgrey}", 
	"{lightgreen}", 
	"{lightpink}", 
	"{lightsalmon}", 
	"{lightseagreen}", 
	"{lightskyblue}", 
	"{lightslategray}", 
	"{lightslategrey}", 
	"{lightsteelblue}", 
	"{lightyellow}", 
	"{lime}", 
	"{limegreen}", 
	"{linen}", 

	"{magenta}", 
	"{maroon}", 
	"{mediumaquamarine}", 
	"{mediumblue}", 
	"{mediumorchid}", 
	"{mediumpurple}", 
	"{mediumseagreen}", 
	"{mediumslateblue}", 
	"{mediumspringgreen}", 
	"{mediumturquoise}", 
	"{mediumvioletred}", 
	"{midnightblue}", 
	"{mintcream}", 
	"{mistyrose}", 
	"{moccasin}", 
	"{mythical}", 

	"{navajowhite}", 
	"{navy}", 
	"{normal}", 

	"{oldlace}", 
	"{olive}", 
	"{olivedrab}", 
	"{orange}", 
	"{orangered}", 
	"{orchid}", 

	"{palegoldenrod}", 
	"{palegreen}", 
	"{paleturquoise}", 
	"{palevioletred}", 
	"{papayawhip}", 
	"{peachpuff}", 
	"{peru}", 
	"{pink}", 
	"{plum}", 
	"{powderblue}", 
	"{purple}", 

	"{rare}", 
	"{red}", 
	"{rosybrown}", 
	"{royalblue}", 

	"{saddlebrown}", 
	"{salmon}", 
	"{sandybrown}", 
	"{seagreen}", 
	"{seashell}", 
	"{selfmade}", 
	"{sienna}", 
	"{silver}", 
	"{skyblue}", 
	"{slateblue}", 
	"{slategray}", 
	"{slategrey}", 
	"{snow}", 
	"{springgreen}", 
	"{steelblue}", 
	"{strange}", 

	"{tan}", 
	"{teal}", 
	"{thistle}", 
	"{tomato}", 
	"{turquoise}", 

	"{uncommon}", 
	"{unique}", 
	"{unusual}", 

	"{valve}", 
	"{vintage}", 
	"{violet}",

	"{wheat}", 
	"{white}", 
	"{whitesmoke}", 

	"{yellow}", 
	"{yellowgreen}", 

	// ( ˊ･ω･` )
	"{fl4n}", 
	"{brz}",

	"{bluegrey}",
	"{grey2}",
	"{lightred}",
	"{palered}",
	"{green}"
};

char gS_CustomColors[][] = 
{
	// A
	"\x07F0F8FF",
	"\x074D7942", // same as Allies team in DoD:S
	"\x07EB4B4B", // same as Ancient item rarity in Dota 2
	"\x07FAEBD7",
	"\x0700FFFF",
	"\x077FFFD4",
	"\x07ADE55C", // same as Arcana item rarity in Dota 2
	"\x07FF4040", // same as Axis team in DoD:S
	"\x07007FFF",
	
	// B
	"\x07F5F5DC",
	"\x07FFE4C4",
	"\x07000000",
	"\x07FFEBCD",
	"\x0799CCFF", // same as BLU/Counter-Terrorist team color
	"\x078A2BE2",
	"\x07A52A2A",
	"\x07DEB887",

	// C
	"\x075F9EA0",
	"\x077FFF00",
	"\x07D2691E",
	"\x07AA0000", // same as Collector's item quality in TF2
	"\x07B0C3D9", // same as Common item rarity in Dota 2
	"\x0770B04A", // same as Community item quality in TF2
	"\x07FF7F50",
	"\x076495ED",
	"\x07FFF8DC",
	"\x07A32C2E", // same as Corrupted item quality in Dota 2
	"\x07DC143C",
	"\x0700FFFF",

	// D
	"\x0700008B",
	"\x07008B8B",
	"\x07B8860B",
	"\x07A9A9A9",
	"\x07A9A9A9",
	"\x07006400",
	"\x07BDB76B",
	"\x078B008B",
	"\x07556B2F",
	"\x07FF8C00",
	"\x079932CC",
	"\x078B0000",
	"\x07E9967A",
	"\x078FBC8F",
	"\x07483D8B",
	"\x072F4F4F",
	"\x072F4F4F",
	"\x0700CED1",
	"\x079400D3",
	"\x07FF1493",
	"\x0700BFFF",
	"\x07696969",
	"\x07696969",
	"\x071E90FF",

	// E
	"\x07CCCCCD", // same as Exalted item quality in Dota 2

	// F
	"\x07B22222",
	"\x07FFFAF0",
	"\x07228B22",
	"\x074983B3", // same as Frozen item quality in Dota 2
	"\x07FF00FF",
	"\x070000FF",
	"\x07FF0000",

	// G
	"\x07DCDCDC",
	"\x074D7455", // same as Genuine item quality in TF2
	"\x07F8F8FF",
	"\x07FFD700",
	"\x07DAA520",
	"\x07CCCCCC", // same as spectator team color
	"\x07CCCCCC",
	"\x07ADFF2F",

	// H
	"\x0738F3AB", // same as Haunted item quality in TF2
	"\x07F0FFF0",
	"\x07FF69B4",

	// I
	"\x07E4AE33", // same as Immortal item rarity in Dota 2
	"\x07CD5C5C",
	"\x074B0082",
	"\x07FFFFF0",

	// K
	"\x07F0E68C",

	// L
	"\x07E6E6FA",
	"\x07FFF0F5",
	"\x077CFC00",
	"\x07D32CE6", // same as Legendary item rarity in Dota 2
	"\x07FFFACD",
	"\x07ADD8E6",
	"\x07F08080",
	"\x07E0FFFF",
	"\x07FAFAD2",
	"\x07D3D3D3",
	"\x07D3D3D3",
	"\x0799FF99",
	"\x07FFB6C1",
	"\x07FFA07A",
	"\x0720B2AA",
	"\x0787CEFA",
	"\x07778899",
	"\x07778899",
	"\x07B0C4DE",
	"\x07FFFFE0",
	"\x0700FF00",
	"\x0732CD32",
	"\x07FAF0E6",

	// M
	"\x07FF00FF",
	"\x07800000",
	"\x0766CDAA",
	"\x070000CD",
	"\x07BA55D3",
	"\x079370D8",
	"\x073CB371",
	"\x077B68EE",
	"\x0700FA9A",
	"\x0748D1CC",
	"\x07C71585",
	"\x07191970",
	"\x07F5FFFA",
	"\x07FFE4E1",
	"\x07FFE4B5",
	"\x078847FF", // same as Mythical item rarity in Dota 2

	// N
	"\x07FFDEAD",
	"\x07000080",
	"\x07B2B2B2", // same as Normal item quality in TF2

	// O
	"\x07FDF5E6",
	"\x079EC34F",
	"\x076B8E23",
	"\x07FFA500",
	"\x07FF4500",
	"\x07DA70D6",
	
	// P
	"\x07EEE8AA",
	"\x0798FB98",
	"\x07AFEEEE",
	"\x07D87093",
	"\x07FFEFD5",
	"\x07FFDAB9",
	"\x07CD853F",
	"\x07FFC0CB",
	"\x07DDA0DD",
	"\x07B0E0E6",
	"\x07800080",

	// R
	"\x074B69FF", // same as Rare item rarity in Dota 
	"\x07FF4040", // same as RED/Terrorist team color
	"\x07BC8F8F",
	"\x074169E1",

	// S
	"\x078B4513",
	"\x07FA8072",
	"\x07F4A460",
	"\x072E8B57",
	"\x07FFF5EE",
	"\x0770B04A", // same as Self-Made item quality in TF2
	"\x07A0522D",
	"\x07C0C0C0",
	"\x0787CEEB",
	"\x076A5ACD",
	"\x07708090",
	"\x07708090",
	"\x07FFFAFA",
	"\x0700FF7F",
	"\x074682B4",
	"\x07CF6A32", // same as Strange item quality in TF
	
	// T
	"\x07D2B48C",
	"\x07008080",
	"\x07D8BFD8",
	"\x07FF6347",
	"\x0740E0D0",

	// U
	"\x07B0C3D9", // same as Uncommon item rarity in Dota 2
	"\x07FFD700", // same as Unique item quality in TF2
	"\x078650AC", // same as Unusual item quality in TF2
	
	// V
	"\x07A50F79", // same as Valve item quality in TF2
	"\x07476291", // same as Vintage item quality in TF2
	"\x07EE82EE",
	
	// W
	"\x07F5DEB3",
	"\x07FFFFFF",
	"\x07F5F5F5",
	
	// Y
	"\x07FFFF00",
	"\x079ACD32",

	// neko
	"\x07FF6A6A",
	"\x076AA6FF",

	// csgo
	"\x076A5ACD",
	"\x07CCCCCC",
	"\x07F93822",
	"\x07CD9294",
	"\x0700FF00"
};

stock void ReplaceColors(char[] string, int size)
{
	for(int x = 0; x < sizeof(gS_GlobalColorNames); x++)
	{
		ReplaceString(string, size, gS_GlobalColorNames[x], gS_GlobalColors[x]);
	}

	for(int x = 0; x < sizeof(gS_CustomColorNames); x++)
	{
		ReplaceString(string, size, gS_CustomColorNames[x], gS_CustomColors[x]);
	}

	ReplaceString(string, size, "{RGB}", "\x07");
	ReplaceString(string, size, "{RGBA}", "\x08");
	ReplaceString(string, size, "{rand}", gS_CustomColors[GetRandomInt(0, sizeof(gS_CustomColors) - 1)]);
}

stock void RemoveColors(char[] string, int size)
{
	for(int x = 0; x < sizeof(gS_GlobalColorNames); x++)
	{
		ReplaceString(string, size, gS_GlobalColorNames[x], "");
	}

	for(int x = 0; x < sizeof(gS_CustomColorNames); x++)
	{
		ReplaceString(string, size, gS_CustomColorNames[x], "");
	}
}