"""Download selected CC0 ambientCG maps; run from repository root."""
from pathlib import Path
import io, urllib.request, zipfile
for asset in ("Concrete012", "Asphalt033"):
    target = Path("assets/textures/cinematic") / asset
    target.mkdir(parents=True, exist_ok=True)
    url = f"https://ambientcg.com/get?file={asset}_2K-JPG.zip"
    req = urllib.request.Request(url, headers={"User-Agent": "O-Ultimo-Refugio/1.0"})
    with urllib.request.urlopen(req, timeout=120) as response:
        data = response.read(100_000_001)
    if len(data) > 100_000_000:
        raise ValueError("Archive exceeds budget")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for suffix, name in (("_Color.jpg","albedo.jpg"),("_NormalGL.jpg","normal.jpg"),("_Roughness.jpg","roughness.jpg")):
            matches = [x for x in archive.namelist() if x.endswith(suffix)]
            if len(matches) != 1:
                raise ValueError(f"{asset}: missing or ambiguous {suffix}")
            if archive.getinfo(matches[0]).file_size > 25_000_000:
                raise ValueError("Map exceeds budget")
            (target / name).write_bytes(archive.read(matches[0]))
    print(f"Imported {asset} (CC0, https://ambientcg.com/view?id={asset})")
