# lizoscan
LizoScan — feed it a list of URLs, it does the rest. Validates live hosts, classifies parameters, then hits everything with nuclei (multi-category), dalfox, sqlmap, crlfuzz, Corsy, ffuf &amp; nikto — full results saved as clean .txt reports. No subdomain enum, no bloat. Bring your own recon. 🎯
# --LizoScan--

Takes a URL list you already have (from your own recon/subdomain tool) and
runs it through parameter classification + a wide spread of vulnerability
scanners — nuclei across many template categories, dalfox, sqlmap, crlfuzz,
Corsy, ffuf, and nikto. All output is saved as `.txt` under `scan results/`.

**No subdomain enumeration happens here.** LizoScan is purely a scanning
stage: bring your own list of URLs and it does the vulnerability testing.

> **Authorized use only.** Run this only against targets you own or have
> explicit written permission to test. Unauthorized scanning is illegal in
> most jurisdictions.

## Files

- `install.sh` — checks which tools are already installed and installs
  only the ones that are missing (idempotent, safe to re-run).
- `lizoscan.sh` — runs the full scanning pipeline against a URL list file.

## Tools used

| Stage                       | Tool(s)                          |
|------------------------------|----------------------------------|
| URL validation (alive check) | `httpx`                          |
| Parameter classification     | `gf` (xss/sqli/ssrf/lfi/redirect/rce/idor/ssti) |
| Vulnerability scanning       | `nuclei` — run separately per category (cves, exposures, misconfiguration, vulnerabilities, default-logins, takeovers, technologies) **and** a full combined run |
| XSS scanning                 | `dalfox`                         |
| SQLi confirmation            | `sqlmap`                         |
| CRLF injection                | `crlfuzz`                        |
| CORS misconfiguration        | `Corsy`                          |
| Hidden content discovery     | `ffuf`                           |
| General web vuln scan        | `nikto`                          |

Every stage checks whether its tool is installed before running, so a
missing tool just skips its stage with a warning instead of breaking the run.

## Usage

```bash
chmod +x install.sh lizoscan.sh

# one-time setup (only installs what's missing)
./install.sh

# scan a URL list you already generated
./lizoscan.sh -l urls.txt

# give the output folder a custom name instead of the input file's name
./lizoscan.sh -l urls.txt -n myscan
```

`urls.txt` is just a plain text file, one URL per line — whatever your
own recon/subdomain tool already outputs.

## Output layout

```
scan results/
└── <scan-name>/              <- named after the input file, or -n value
    ├── urls/
    │   ├── input_urls.txt    <- your original list, deduped
    │   ├── valid_urls.txt    <- httpx output (status, title, tech)
    │   └── alive_urls.txt    <- just the live URLs
    ├── params/
    │   ├── urls_with_params.txt
    │   └── gf_<pattern>.txt  <- xss / sqli / ssrf / lfi / redirect / rce / idor / ssti
    ├── vuln/
    │   ├── nuclei/
    │   │   ├── cves_results.txt
    │   │   ├── exposures_results.txt
    │   │   ├── misconfiguration_results.txt
    │   │   ├── vulnerabilities_results.txt
    │   │   ├── default_logins_results.txt
    │   │   ├── takeovers_results.txt
    │   │   ├── technologies_results.txt
    │   │   └── full_results.txt
    │   ├── nuclei_results.txt   <- deduped union of everything in nuclei/
    │   ├── dalfox_results.txt
    │   ├── sqlmap_results.txt
    │   ├── crlf_results.txt
    │   ├── cors_results.txt
    │   ├── ffuf_results.txt
    │   └── nikto_results.txt
    └── report.txt             <- consolidated summary of everything above
```

## Notes

- `install.sh` never reinstalls a tool that's already on your `$PATH`.
- Running nuclei per-tag as well as a full run means you get both a
  categorized breakdown and a complete result set in one pass.
