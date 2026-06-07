-- Star catalog (Yale BSC subset) + simplified sky math
-- Virtual field: 2400 × 720 px  (100 px/hr RA, 4 px/deg Dec)
-- vx = ra*100,  vy = (90-dec)*4

local Stars = {}

Stars.FIELD_W = 2400
Stars.FIELD_H = 720

-- {ra_hours, dec_deg, mag}
local CATALOG = {
  -- Canis Major
  { 6.7525, -16.7161, -1.46},  -- Sirius
  { 6.9771, -28.9722,  1.50},  -- Adhara
  { 7.1397, -26.3932,  1.83},  -- Wezen
  { 7.4018, -29.3031,  2.45},  -- Aludra
  { 6.3384, -30.0634,  3.02},  -- Furud
  -- Carina
  { 6.3992, -52.6957, -0.72},  -- Canopus
  { 9.2197, -69.7172,  1.67},  -- Miaplacidus
  { 8.3752, -59.5098,  1.86},  -- Avior
  { 9.2843, -59.2752,  2.25},  -- Aspidiske
  { 7.9466, -52.9818,  2.76},  -- Tureis
  -- Centaurus
  {14.6595, -60.8328, -0.01},  -- Alpha Centauri
  {14.0637, -60.3730,  0.60},  -- Hadar (Beta Cen)
  {14.1115, -36.3699,  2.06},  -- Menkent
  {12.1414, -50.7225,  2.17},  -- Muhlifain
  {13.6646, -53.4664,  2.30},  -- Epsilon Centauri
  {14.5923, -42.1578,  2.31},  -- Eta Centauri
  {14.9939, -42.1046,  2.55},  -- Theta Centauri
  -- Boötes
  {14.2611,  19.1822, -0.05},  -- Arcturus
  {14.7498,  27.0743,  2.35},  -- Izar
  {13.9115,  18.3977,  2.68},  -- Muphrid
  {14.5348,  38.3082,  3.04},  -- Seginus
  {15.0326,  40.3904,  3.49},  -- Nekkar
  -- Lyra
  {18.6157,  38.7836,  0.03},  -- Vega
  {18.9821,  32.6896,  3.25},  -- Sulafat
  {18.8348,  33.3627,  3.52},  -- Sheliak
  -- Auriga
  { 5.2784,  45.9980,  0.08},  -- Capella
  { 5.9921,  44.9474,  1.90},  -- Menkalinan
  { 5.9926,  37.2124,  2.62},  -- Theta Aurigae
  { 5.0321,  43.8231,  2.99},  -- Hassaleh
  -- Orion
  { 5.2432,  -8.2016,  0.13},  -- Rigel
  { 5.9195,   7.4069,  0.42},  -- Betelgeuse
  { 5.4188,   6.3497,  1.64},  -- Bellatrix
  { 5.6036,  -1.2019,  1.69},  -- Alnilam
  { 5.6792,  -1.9428,  1.74},  -- Alnitak
  { 5.7954,  -9.6697,  2.07},  -- Saiph
  { 5.5335,  -0.2991,  2.23},  -- Mintaka
  { 5.5883,   9.9342,  3.39},  -- Meissa
  { 5.4083,  -2.3978,  3.69},  -- Eta Orionis
  -- Gemini
  { 7.7554,  28.0262,  1.14},  -- Pollux
  { 7.5767,  31.8883,  1.58},  -- Castor
  { 6.6289,  16.3993,  1.93},  -- Alhena
  { 7.3355,  21.9823,  3.53},  -- Wasat
  { 6.7310,  25.1312,  3.06},  -- Mebsuda
  { 6.3822,  22.5136,  3.35},  -- Propus
  { 7.1863,  16.1404,  3.36},  -- Tejat
  -- Canis Minor
  { 7.6553,   5.2250,  0.34},  -- Procyon
  { 7.4526,   8.2894,  2.89},  -- Gomeisa
  -- Taurus
  { 4.5987,  16.5093,  0.85},  -- Aldebaran
  { 5.4382,  28.6076,  1.65},  -- Elnath
  { 5.6274,  21.1426,  3.00},  -- Zeta Tauri
  { 3.7914,  24.1050,  2.87},  -- Alcyone (Pleiades)
  { 3.7721,  24.1138,  3.63},  -- Atlas
  { 3.7346,  23.9477,  3.70},  -- Electra
  { 4.4768,  15.9719,  3.47},  -- Ain
  -- Leo
  {10.1395,  11.9672,  1.35},  -- Regulus
  {11.8181,  14.5720,  2.14},  -- Denebola
  {11.2352,  20.5238,  2.56},  -- Zosma
  {10.3328,  19.8417,  2.61},  -- Algieba
  {11.2350,  15.4297,  3.34},  -- Chertan
  {10.8228,   6.0292,  3.52},  -- Chort
  {10.1228,  16.7625,  3.85},  -- Eta Leonis
  -- Virgo
  {13.4199, -11.1613,  0.97},  -- Spica
  {13.0362,  10.9591,  2.83},  -- Vindemiatrix
  {12.6941,  -1.4494,  2.74},  -- Porrima
  {13.5782,  -0.5958,  3.38},  -- Heze
  {12.3317,  -0.6668,  3.61},  -- Zaniah
  -- Scorpius
  {16.4901, -26.4320,  1.09},  -- Antares
  {17.5600, -37.1032,  1.62},  -- Shaula
  {17.6222, -42.9979,  1.87},  -- Sargas
  {16.8357, -34.2931,  2.29},  -- Epsilon Scorpii
  {16.0053, -22.6217,  2.32},  -- Dschubba
  {16.0879, -19.8054,  2.62},  -- Grafias
  {17.7081, -39.0302,  2.69},  -- Eta Scorpii
  {16.3527, -25.5924,  2.82},  -- Tau Scorpii
  {15.9809, -26.1142,  2.89},  -- Pi Scorpii
  -- Sagittarius
  {18.4028, -34.3843,  1.79},  -- Kaus Australis
  {18.9212, -26.2967,  2.05},  -- Nunki
  {19.0433, -29.8803,  2.59},  -- Ascella
  {18.3490, -29.8281,  2.70},  -- Kaus Media
  {18.2935, -25.4217,  2.81},  -- Kaus Borealis
  {19.1628, -21.0236,  2.88},  -- Pi Sagittarii
  {18.0989, -30.4238,  2.99},  -- Alnasl
  {18.4608, -26.9865,  3.17},  -- Phi Sagittarii
  -- Cygnus
  {20.6905,  45.2803,  1.25},  -- Deneb
  {20.3703,  40.2567,  2.23},  -- Sadr
  {20.7704,  33.9703,  2.46},  -- Gienah Cygni
  {19.7496,  45.1303,  2.87},  -- Delta Cygni
  {19.5121,  27.9597,  3.08},  -- Albireo
  {21.2156,  30.2270,  3.20},  -- Zeta Cygni
  -- Aquila
  {19.8463,   8.8683,  0.77},  -- Altair
  {19.7709,  10.6133,  2.72},  -- Tarazed
  {19.0901,  13.8633,  2.99},  -- Okab
  -- Crux
  {12.4433, -63.0991,  0.77},  -- Acrux
  {12.7952, -59.6889,  1.25},  -- Mimosa
  {12.5194, -57.1132,  1.59},  -- Gacrux
  {12.3527, -58.7489,  2.79},  -- Delta Crucis
  -- Perseus
  { 3.4053,  49.8612,  1.79},  -- Mirfak
  { 3.1361,  40.9557,  2.12},  -- Algol
  { 3.9024,  31.8836,  2.85},  -- Zeta Persei
  { 4.1499,  47.7126,  3.80},  -- Miram
  -- Cassiopeia
  { 0.6752,  56.5373,  2.24},  -- Schedar
  { 0.1530,  59.1498,  2.28},  -- Caph
  { 0.9453,  60.7167,  2.47},  -- Gamma Cassiopeiae
  { 1.4304,  60.2353,  2.68},  -- Ruchbah
  { 1.9073,  63.6701,  3.38},  -- Segin
  -- Ursa Major
  {12.9005,  55.9598,  1.76},  -- Alioth
  {11.0621,  61.7509,  1.79},  -- Dubhe
  {13.7923,  49.3133,  1.86},  -- Alkaid
  {13.3988,  54.9254,  2.27},  -- Mizar
  {11.0307,  56.3824,  2.37},  -- Merak
  {11.8977,  53.6948,  2.44},  -- Phecda
  {12.2571,  57.0326,  3.31},  -- Megrez
  {13.4207,  54.9879,  3.99},  -- Alcor
  -- Ursa Minor
  { 2.5303,  89.2641,  1.97},  -- Polaris
  {14.8451,  74.1553,  2.08},  -- Kochab
  {15.3456,  71.8340,  3.00},  -- Pherkad
  -- Andromeda
  { 0.1398,  29.0905,  2.07},  -- Alpheratz
  { 1.1622,  35.6205,  2.07},  -- Mirach
  { 2.0651,  42.3298,  2.26},  -- Almach
  -- Eridanus
  { 1.6285, -57.2366,  0.46},  -- Achernar
  { 2.9714, -40.3048,  3.24},  -- Acamar
  { 5.1320,  -5.0862,  2.79},  -- Cursa
  { 4.2987, -33.7986,  3.89},  -- Zaurak
  -- Piscis Austrinus
  {22.9608, -29.6223,  1.16},  -- Fomalhaut
  -- Pegasus
  {23.0793,  15.1834,  2.49},  -- Markab
  {23.0629,  28.0827,  2.44},  -- Scheat
  {21.7364,   9.8749,  2.38},  -- Enif
  { 0.2211,  15.1836,  2.83},  -- Algenib
  {22.6909,  10.8314,  3.40},  -- Homam
  -- Aries
  { 2.1196,  23.4624,  2.00},  -- Hamal
  { 1.9107,  20.8081,  2.64},  -- Sheratan
  -- Cetus
  { 2.7219,   3.2361,  2.04},  -- Diphda
  -- Phoenix
  { 0.4361, -42.3060,  2.40},  -- Ankaa
  -- Grus
  {22.1372, -46.9606,  1.73},  -- Alnair
  {22.7115, -46.8848,  2.07},  -- Beta Gruis
  -- Pavo
  {20.4275, -56.7349,  1.94},  -- Peacock
  -- Triangulum Australe
  {16.8109, -69.0277,  1.91},  -- Atria
  -- Pavo addl.
  {18.7172, -71.4278,  3.61},  -- Delta Pavonis
  -- Ophiuchus
  {17.5823,  12.5600,  2.08},  -- Rasalhague
  {17.1729, -15.7247,  2.43},  -- Sabik
  {16.3054,  -3.6942,  2.74},  -- Yed Prior
  {17.3668, -24.9993,  2.54},  -- Eta Ophiuchi
  {16.9376, -10.5676,  3.19},  -- Zeta Ophiuchi
  -- Hercules
  {16.5036,  21.4896,  2.78},  -- Kornephoros
  {16.6883,  31.6033,  2.81},  -- Zeta Herculis
  {17.2440,  14.3903,  3.16},  -- Sarin
  -- Draco
  {17.9434,  51.4890,  2.24},  -- Eltanin
  {17.5073,  52.3014,  2.79},  -- Rastaban
  {14.0733,  64.3758,  3.65},  -- Thuban
  {11.5232,  69.3312,  3.29},  -- Aldhibah
  -- Libra
  {14.8479, -16.0418,  2.75},  -- Zubenelgenubi
  {15.2836,  -9.3830,  2.61},  -- Zubeneschamali
  {15.0680, -25.2817,  3.29},  -- Sigma Librae
  -- Serpens
  {15.7378,   6.4258,  2.65},  -- Unukalhai
  -- Corona Borealis
  {15.5780,  26.7148,  2.22},  -- Alphecca
  -- Hydra
  { 9.4598,  -8.6585,  1.98},  -- Alphard
  -- Corvus
  {12.1684, -22.6198,  2.58},  -- Gienah Corvi
  {12.5758, -23.3966,  2.65},  -- Algorab
  {12.4972, -16.5152,  2.94},  -- Kraz
  -- Cepheus
  {21.3097,  62.5854,  2.45},  -- Alderamin
  {22.8282,  66.2003,  3.23},  -- Alfirk
  -- Capricornus
  {21.7844, -16.1274,  2.85},  -- Deneb Algedi
  {21.0999, -17.2327,  3.08},  -- Dabih
  -- Aquarius
  {21.5258,  -5.5712,  2.90},  -- Sadalsuud
  {22.0961,  -0.3197,  2.96},  -- Sadalmelik
  {22.8771,  -7.5797,  3.27},  -- Skat
  -- Lupus
  {14.6986, -47.3882,  2.30},  -- Alpha Lupi
  {14.9759, -43.1339,  2.68},  -- Beta Lupi
  -- Vela
  { 8.1587, -47.3366,  1.72},  -- Gamma Velorum
  { 8.7449, -54.7087,  1.93},  -- Delta Velorum
  { 9.3692, -55.0106,  2.47},  -- Kappa Velorum
  -- Puppis
  { 8.0594, -40.0031,  2.25},  -- Naos
  { 7.8216, -24.8598,  3.17},  -- Azmidi
  { 7.7168, -28.9544,  2.70},  -- Pi Puppis
  -- Ara
  {16.9778, -55.9899,  2.84},  -- Beta Arae
  {17.4225, -49.8759,  2.95},  -- Alpha Arae
  -- Cygnus (more)
  {20.9270,  41.1673,  2.46},  -- Epsilon Cygni
}

-- Display names aligned 1-to-1 with CATALOG entries
local NAMES = {
  -- Canis Major
  "Sirius","Adhara","Wezen","Aludra","Furud",
  -- Carina
  "Canopus","Miaplacidus","Avior","Aspidiske","Tureis",
  -- Centaurus
  "Alpha Cen","Hadar","Menkent","Muhlifain","Epsilon Cen","Eta Cen","Theta Cen",
  -- Boötes
  "Arcturus","Izar","Muphrid","Seginus","Nekkar",
  -- Lyra
  "Vega","Sulafat","Sheliak",
  -- Auriga
  "Capella","Menkalinan","Theta Aur","Hassaleh",
  -- Orion
  "Rigel","Betelgeuse","Bellatrix","Alnilam","Alnitak","Saiph","Mintaka","Meissa","Eta Ori",
  -- Gemini
  "Pollux","Castor","Alhena","Wasat","Mebsuda","Propus","Tejat",
  -- Canis Minor
  "Procyon","Gomeisa",
  -- Taurus
  "Aldebaran","Elnath","Zeta Tau","Alcyone","Atlas","Electra","Ain",
  -- Leo
  "Regulus","Denebola","Zosma","Algieba","Chertan","Chort","Eta Leo",
  -- Virgo
  "Spica","Vindemiatrix","Porrima","Heze","Zaniah",
  -- Scorpius
  "Antares","Shaula","Sargas","Epsilon Sco","Dschubba","Grafias","Eta Sco","Tau Sco","Pi Sco",
  -- Sagittarius
  "Kaus Aus.","Nunki","Ascella","Kaus Media","Kaus Bor.","Pi Sgr","Alnasl","Phi Sgr",
  -- Cygnus
  "Deneb","Sadr","Gienah Cyg","Delta Cyg","Albireo","Zeta Cyg",
  -- Aquila
  "Altair","Tarazed","Okab",
  -- Crux
  "Acrux","Mimosa","Gacrux","Delta Cru",
  -- Perseus
  "Mirfak","Algol","Zeta Per","Miram",
  -- Cassiopeia
  "Schedar","Caph","Gamma Cas","Ruchbah","Segin",
  -- Ursa Major
  "Alioth","Dubhe","Alkaid","Mizar","Merak","Phecda","Megrez","Alcor",
  -- Ursa Minor
  "Polaris","Kochab","Pherkad",
  -- Andromeda
  "Alpheratz","Mirach","Almach",
  -- Eridanus
  "Achernar","Acamar","Cursa","Zaurak",
  -- Piscis Austrinus
  "Fomalhaut",
  -- Pegasus
  "Markab","Scheat","Enif","Algenib","Homam",
  -- Aries
  "Hamal","Sheratan",
  -- Cetus
  "Diphda",
  -- Phoenix
  "Ankaa",
  -- Grus
  "Alnair","Beta Gru",
  -- Pavo
  "Peacock",
  -- Triangulum Australe
  "Atria",
  -- Pavo addl.
  "Delta Pav",
  -- Ophiuchus
  "Rasalhague","Sabik","Yed Prior","Eta Oph","Zeta Oph",
  -- Hercules
  "Kornephoros","Zeta Her","Sarin",
  -- Draco
  "Eltanin","Rastaban","Thuban","Aldhibah",
  -- Libra
  "Zubenel.","Zubenesc.","Sigma Lib",
  -- Serpens
  "Unukalhai",
  -- Corona Borealis
  "Alphecca",
  -- Hydra
  "Alphard",
  -- Corvus
  "Gienah Cor","Algorab","Kraz",
  -- Cepheus
  "Alderamin","Alfirk",
  -- Capricornus
  "Deneb Alg.","Dabih",
  -- Aquarius
  "Sadalsuud","Sadalmelik","Skat",
  -- Lupus
  "Alpha Lup","Beta Lup",
  -- Vela
  "Gamma Vel","Delta Vel","Kappa Vel",
  -- Puppis
  "Naos","Azmidi","Pi Pup",
  -- Ara
  "Beta Ara","Alpha Ara",
  -- Cygnus (more)
  "Epsilon Cyg",
}

local _all = nil  -- loaded once

local function mag_to_brightness(m)
  -- Map magnitude to linear 0-1. Sirius (-1.46) ≈ 1.0; mag 5 ≈ 0.03
  return math.max(0.03, math.min(1.0, math.pow(10, (-m - 1.5) * 0.3)))
end

-- Julian Date from calendar
local function jd(y, mo, d, h)
  if mo <= 2 then y = y - 1; mo = mo + 12 end
  local A = math.floor(y / 100)
  local B = 2 - A + math.floor(A / 4)
  return math.floor(365.25 * (y + 4716)) + math.floor(30.6001 * (mo + 1)) + d + h / 24 + B - 1524.5
end

-- Greenwich Mean Sidereal Time (hours)
local function gmst(julian)
  local T = (julian - 2451545.0) / 36525.0
  local g = 280.46061837 + 360.98564736629 * (julian - 2451545.0) + 0.000387933 * T * T
  return ((g % 360) + 360) % 360 / 15
end

-- Altitude for hour angle, declination, latitude (degrees in, degrees out)
local function altitude(ha_deg, dec_deg, lat_deg)
  local ha  = math.rad(ha_deg)
  local dec = math.rad(dec_deg)
  local lat = math.rad(lat_deg)
  local s   = math.sin(dec) * math.sin(lat) + math.cos(dec) * math.cos(lat) * math.cos(ha)
  return math.deg(math.asin(math.max(-1.0, math.min(1.0, s))))
end

-- Load catalog + procedural background into _all (call once at startup)
function Stars.load()
  _all = {}
  math.randomseed(9876)  -- fixed seed so dice values are consistent per session

  for i, s in ipairs(CATALOG) do
    table.insert(_all, {
      id         = i,
      ra         = s[1],
      dec        = s[2],
      mag        = s[3],
      name       = NAMES[i],
      vx         = (s[1] * 100) % Stars.FIELD_W,
      vy         = (90 - s[2]) * 4,
      brightness = mag_to_brightness(s[3]),
      dice       = math.random(),
      is_bg      = false,
    })
  end

  -- Procedural background (Milky Way weighted distribution, fixed positions)
  math.randomseed(1234)
  for i = 1, 420 do
    local ra  = math.random() * 24
    -- Milky Way peaks near RA 18-21h (summer) and 5-6h (winter)
    local gal = math.sin((ra / 24) * 2 * math.pi * 1.35 - 0.6) * 22
    local dec = gal + (math.random() - 0.5) * 38
    dec = math.max(-82, math.min(82, dec))
    local mag = 4.0 + math.random() * 2.0
    table.insert(_all, {
      id         = #CATALOG + i,
      ra         = ra,
      dec        = dec,
      mag        = mag,
      vx         = (ra * 100) % Stars.FIELD_W,
      vy         = (90 - dec) * 4,
      brightness = 0.03 + math.random() * 0.13,
      dice       = math.random(),
      is_bg      = true,
      -- parallax factor: far bg stars pan slightly slower than named stars.
      -- deterministic hash so dice sequence above is unchanged.
      par        = 0.82 + ((i * 73 + math.floor(ra * 31)) % 150) / 1000.0,
    })
  end
end

-- Return all loaded stars (full atlas, not filtered by horizon).
-- The date/location only governs the initial pan position via default_pan().
-- Cage's original used the full atlas as score, not the live visible sky.
function Stars.compute()
  return _all
end

-- Default pan position: center screen on stars transiting the local meridian
-- and on the observer's declination (latitude).
function Stars.default_pan(year, month, day, hour, lat, lon)
  local julian = jd(year, month, day, hour)
  local lst    = (gmst(julian) + lon / 15 + 24) % 24
  local pan_x  = ((lst * 100 - 64) % Stars.FIELD_W + Stars.FIELD_W) % Stars.FIELD_W
  local pan_y  = math.max(0, math.min(Stars.FIELD_H - 64, (90 - lat) * 4 - 32))
  return pan_x, pan_y
end

-- Constellation line segments {vx1,vy1, vx2,vy2} for 7 constellations.
-- Uses named-star RA/Dec so these are always par=1.0 positions.
-- Drawn by UI when zoom <= 1.5.
do
  local function c(r1,d1, r2,d2)
    return {(r1*100)%2400, (90-d1)*4, (r2*100)%2400, (90-d2)*4}
  end
  Stars.CONST_LINES = {
    -- ── Orion ─────────────────────────────────────────────────────
    c( 5.5883, 9.9342,  5.9195, 7.4069),  -- Meissa   – Betelgeuse
    c( 5.9195, 7.4069,  5.4188, 6.3497),  -- Betelgeuse – Bellatrix
    c( 5.9195, 7.4069,  5.5335,-0.2991),  -- Betelgeuse – Mintaka
    c( 5.4188, 6.3497,  5.6792,-1.9428),  -- Bellatrix – Alnitak
    c( 5.5335,-0.2991,  5.6036,-1.2019),  -- Mintaka  – Alnilam
    c( 5.6036,-1.2019,  5.6792,-1.9428),  -- Alnilam  – Alnitak
    c( 5.6792,-1.9428,  5.2432,-8.2016),  -- Alnitak  – Rigel
    c( 5.5335,-0.2991,  5.7954,-9.6697),  -- Mintaka  – Saiph
    c( 5.2432,-8.2016,  5.7954,-9.6697),  -- Rigel    – Saiph
    -- ── Ursa Major ────────────────────────────────────────────────
    c(11.0621,61.7509, 11.0307,56.3824),  -- Dubhe  – Merak
    c(11.0307,56.3824, 11.8977,53.6948),  -- Merak  – Phecda
    c(11.8977,53.6948, 12.2571,57.0326),  -- Phecda – Megrez
    c(12.2571,57.0326, 11.0621,61.7509),  -- Megrez – Dubhe (close bowl)
    c(12.2571,57.0326, 12.9005,55.9598),  -- Megrez – Alioth
    c(12.9005,55.9598, 13.3988,54.9254),  -- Alioth – Mizar
    c(13.3988,54.9254, 13.7923,49.3133),  -- Mizar  – Alkaid
    -- ── Cassiopeia ────────────────────────────────────────────────
    c( 0.1530,59.1498,  0.6752,56.5373),  -- Caph    – Schedar
    c( 0.6752,56.5373,  0.9453,60.7167),  -- Schedar – Gamma Cas
    c( 0.9453,60.7167,  1.4304,60.2353),  -- Gamma   – Ruchbah
    c( 1.4304,60.2353,  1.9073,63.6701),  -- Ruchbah – Segin
    -- ── Scorpius ──────────────────────────────────────────────────
    c(15.9809,-26.1142, 16.0053,-22.6217),  -- Pi     – Dschubba
    c(16.0879,-19.8054, 16.0053,-22.6217),  -- Grafias– Dschubba
    c(16.0053,-22.6217, 16.4901,-26.4320),  -- Dschubba–Antares
    c(16.4901,-26.4320, 16.3527,-25.5924),  -- Antares– Tau Sco
    c(16.3527,-25.5924, 16.8357,-34.2931),  -- Tau    – Epsilon
    c(16.8357,-34.2931, 17.7081,-39.0302),  -- Epsilon– Eta
    c(17.7081,-39.0302, 17.5600,-37.1032),  -- Eta    – Shaula
    c(17.5600,-37.1032, 17.6222,-42.9979),  -- Shaula – Sargas
    -- ── Leo ───────────────────────────────────────────────────────
    c(10.1228,16.7625, 10.3328,19.8417),  -- Eta Leo– Algieba
    c(10.3328,19.8417, 10.1395,11.9672),  -- Algieba– Regulus
    c(10.1395,11.9672, 10.1228,16.7625),  -- Regulus– Eta Leo (close sickle)
    c(10.3328,19.8417, 11.2352,20.5238),  -- Algieba– Zosma
    c(11.2352,20.5238, 11.8181,14.5720),  -- Zosma  – Denebola
    c(11.2352,20.5238, 11.2350,15.4297),  -- Zosma  – Chertan
    c(11.2350,15.4297, 10.8228, 6.0292),  -- Chertan– Chort
    -- ── Cygnus ────────────────────────────────────────────────────
    c(20.6905,45.2803, 20.3703,40.2567),  -- Deneb      – Sadr
    c(20.3703,40.2567, 19.5121,27.9597),  -- Sadr       – Albireo
    c(20.7704,33.9703, 20.3703,40.2567),  -- Gienah Cyg – Sadr
    c(20.3703,40.2567, 19.7496,45.1303),  -- Sadr       – Delta Cyg
    c(20.9270,41.1673, 20.7704,33.9703),  -- Epsilon    – Gienah
    -- ── Crux ──────────────────────────────────────────────────────
    c(12.5194,-57.1132, 12.4433,-63.0991),  -- Gacrux – Acrux (vertical)
    c(12.7952,-59.6889, 12.3527,-58.7489),  -- Mimosa – Delta Cru (horizontal)
  }
end

return Stars
