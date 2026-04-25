import asyncio
import json
import re
import os
from playwright.async_api import async_playwright

# Known name discrepancies between PPA athletes page and Pickleball.com
NICKNAME_MAP = {
    "TAMMY EMMRICH": "Tamaryn Emmrich",
    "MAXWELL FREEMAN": "Max Freeman",
    "JHONNATAN MEDINA ALVAREZ": "Jhonnatan Medina Alvarez",
    "CAMDEN CHAFFIN": "Camden Chaffin", # Ensure correct slug resolution
    "ANDRE MERCADO": "Andre Mercado",
    "CAILYN CAMPBELL": "Cailyn Campbell",
    "ANDREW CALDARELLA": "Andrew Caldarella",
    "EMMA NELSON": "Emma Nelson",
    "TAMA SHIMABUKURO": "Tama Shimabukuro",
    "ELLA YEH": "Ella Yeh",
    "WES BURROWS": "Wesley Burrows",
    "GREG DOW": "Gregory Dow",
    "ALLI PHILLIPS": "Allison Phillips",
    "PIERI IMPARATO": "Pierina Imparato",
    "PAULA RIVES": "Paula Rives Rodriguez"
}

async def scrape_ppa_athletes():
    """
    Scrape the full list of active PPA pros from https://ppatour.com/athletes/.
    Returns a list of player names in the order they appear on the page.
    This is the authoritative source (~160 signed/active pros) used to
    focus downstream DUPR and pickleball.com scraping.
    """
    url = "https://ppatour.com/athletes/"
    players = []

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )
        page = await context.new_page()

        print(f"Navigating to {url}...", flush=True)
        try:
            await page.goto(url, wait_until="networkidle", timeout=60000)
        except Exception as e:
            print(f"Networkidle timeout: {e}. Falling back to domcontentloaded...", flush=True)
            await page.goto(url, wait_until="domcontentloaded", timeout=60000)

        # All athletes are on a single page — no pagination needed.
        await page.wait_for_selector('.featured-players__athlete-name', timeout=30000)

        raw = await page.evaluate("""
            () => {
                const cards = Array.from(document.querySelectorAll('a.featured-players__link'));
                return cards.map(card => ({
                    name: (card.querySelector('.featured-players__athlete-name')
                            ?.innerText || '').trim(),
                    category: (card.querySelector('.featured-players__athlete-tournament')
                                ?.innerText || '').trim()
                })).filter(p => p.name.length > 0);
            }
        """)

        seen = set()
        for entry in raw:
            if entry['name'] not in seen:
                seen.add(entry['name'])
                players.append(entry['name'])

        print(f"Found {len(players)} active PPA pros on athletes page.", flush=True)
        await browser.close()

    return players

def format_player_name_for_url(name):
    """
    Format name for Pickleball.com URL using all parts.
    Example: "Anna Leigh Waters" -> "anna-leigh-waters"
    """
    # Check for nickname first
    formal_name = NICKNAME_MAP.get(name.upper(), name)
    
    # Remove any non-alphanumeric characters except spaces and hyphens
    clean_name = re.sub(r'[^a-zA-Z0-9\s\-]', '', formal_name.strip().lower())
    # Replace multiple spaces/hyphens with a single hyphen
    url_name = re.sub(r'[\s\-]+', '-', clean_name)
    return url_name

async def resolve_player_slugs(page, name):
    """
    Search for all candidate slugs for a player name.
    1. Try the default slug.
    2. Try common suffixes (-1, -2, -3, -4, -5).
    Returns (candidates_list, slug_to_dupr_map).
    """
    candidates = []
    slug_dupr_map = {}  # slug -> DUPR ID from search results
    default_slug = format_player_name_for_url(name)
    candidates.append(default_slug)
    
    # Common suffixes used by Pickleball.com for duplicate/merged profiles
    for i in range(1, 6):
        candidates.append(f"{default_slug}-{i}")
    
    unique_candidates = list(dict.fromkeys(candidates))
    print(f"  [OK] Final candidate list for {name}: {unique_candidates}", flush=True)
    return unique_candidates, slug_dupr_map


async def extract_profile_info(page):
    """Extract player profile details (Gender, Age, etc.) excluding Sponsor."""
    return await page.evaluate("""
        () => {
            const profile = {};
            const labels = ['Gender', 'Age', 'Resides', 'Height', 'DUPR ID', 'Turned Pro', 'Plays'];
            const allElements = Array.from(document.querySelectorAll('div, span, p'));
            
            labels.forEach(label => {
                const labelEl = allElements.find(el => {
                    const text = el.innerText || '';
                    return text.trim() === label && !el.querySelector('*');
                });
                if (labelEl) {
                    let container = labelEl.parentElement;
                    const valueEl = container.querySelector('span');
                    if (valueEl) {
                        profile[label] = valueEl.innerText ? valueEl.innerText.trim() : 'N/A';
                    } else {
                        let sibling = labelEl.nextElementSibling;
                        profile[label] = (sibling && sibling.innerText) ? sibling.innerText.trim() : 'N/A';
                    }
                } else {
                    profile[label] = 'N/A';
                }
            });
            return profile;
        }
    """)

async def extract_rankings_table(page):
    """Extract Division-specific rankings (Doubles, Mixed, Singles)."""
    return await page.evaluate("""
        () => {
            const results = [];
            const table = document.querySelector('table');
            if (table) {
                const rows = Array.from(table.querySelectorAll('tr')).slice(1);
                rows.forEach(row => {
                    const cells = Array.from(row.querySelectorAll('td, th')).map(c => c.innerText.trim());
                    if (cells.length >= 4) {
                        results.push({
                            Division: cells[0] || 'N/A',
                            Rank: cells[1] || 'N/A',
                            Points: cells[2] || 'N/A',
                            Rating: cells[3] || 'N/A',
                            Gold: cells[4] || '0',
                            Silver: cells[5] || '0',
                            Bronze: cells[6] || '0',
                            Total: cells[7] || '0'
                        });
                    }
                });
            }
            return results;
        }
    """)

async def extract_match_stats(page):
    """Extract Win-Loss for the selected division."""
    return await page.evaluate("""
        () => {
            const data = {};
            // Look for stats within the specific container that updates
            const container = document.querySelector('div.bg-card') || document;
            const items = ['Win-Loss', 'Longest win streak', 'Upset wins'];
            const allDivs = Array.from(container.querySelectorAll('div, span'));
            
            items.forEach(item => {
                const el = allDivs.find(e => e.innerText.trim() === item && !e.querySelector('*'));
                if (el) {
                    let val = 'N/A';
                    if (el.nextElementSibling) {
                        val = el.nextElementSibling.innerText.trim();
                    } else if (el.parentElement && el.parentElement.nextElementSibling) {
                        val = el.parentElement.nextElementSibling.innerText.trim();
                    }
                    data[item] = val;
                } else {
                    data[item] = 'N/A';
                }
            });
            return data;
        }
    """)

async def extract_titles_finals(page, division_name: str = ""):
    """
    Extract division-specific Titles and Finals.
    Strategy:
    1. Find the Titles & Finals section heading, then look inside it for rows
       that contain medal counts (Gold / Silver / Bronze columns).
    2. Fallback: walk the Rankings table for the matching division row and read
       Gold/Silver/Bronze/Total from there (those values are always correct).
    """
    return await page.evaluate("""
        (divisionName) => {
            const stats = { "Gold": "0", "Silver": "0", "Bronze": "0", "Titles": "0", "Finals": "0" };
            const globalMedals = {};

            // ── Strategy 1: Div-based "Table" (Pickleball.com uses flex-divs) ──
            const allDivs = Array.from(document.querySelectorAll('div.flex.w-full.items-center.justify-between'));
            
            // Find Total Row
            const totalRow = allDivs.find(d => {
                const text = (d.innerText || '').trim();
                return text.startsWith('Total') && d.innerText.includes('Gold');
            });

            if (totalRow) {
                // Find medal counts near their respective images OR by parsing text
                const text = (totalRow.innerText || '').trim();
                // Match patterns like "61Gold", "11Silver", etc. or just numbers before words
                const goldMatch   = text.match(/(\\d+)\\s*(Gold|Gold)/i);
                const silverMatch = text.match(/(\\d+)\\s*(Silver|Silver)/i);
                const bronzeMatch = text.match(/(\\d+)\\s*(Bronze|Bronze)/i);
                
                if (goldMatch) stats["Gold"] = goldMatch[1];
                if (silverMatch) stats["Silver"] = silverMatch[1];
                if (bronzeMatch) stats["Bronze"] = bronzeMatch[1];
                
                stats["Titles"] = stats["Gold"];
                stats["Finals"] = (parseInt(stats["Gold"]) + parseInt(stats["Silver"])).toString();
            }

            // ── Strategy 2: Global Medal Counts ──
            const allRows = Array.from(document.querySelectorAll('div.flex.w-full.items-center.justify-between'));
            allRows.forEach(row => {
                const text = (row.innerText || '').trim().toLowerCase();
                if (text.includes('won 1 medal') || text.includes('won 2 medals') || text.includes('triple crown')) {
                    const countMatch = text.match(/(\\d+)$/);
                    const label = text.includes('won 1 medal') ? "Won 1 medal" : 
                                  text.includes('won 2 medals') ? "Won 2 medals" : "Triple Crowns";
                    if (countMatch) globalMedals[label] = countMatch[1];
                }
            });

            // ── Strategy 3: Rankings table fallback (Original logic) ──
            const allZero = stats["Gold"] === '0' && stats["Silver"] === '0' && stats["Bronze"] === '0';
            if (allZero && divisionName) {
                const rankTable = document.querySelector('table');
                if (rankTable) {
                    const rows = Array.from(rankTable.querySelectorAll('tr')).slice(1);
                    for (const row of rows) {
                        const cells = Array.from(row.querySelectorAll('td, th')).map(c => c.innerText.trim());
                        if (cells.length >= 8 && cells[0].toLowerCase() === divisionName.toLowerCase()) {
                            stats["Gold"]   = cells[4];
                            stats["Silver"] = cells[5];
                            stats["Bronze"] = cells[6];
                            stats["Titles"] = stats["Gold"];
                            stats["Finals"] = (parseInt(stats["Gold"]) + parseInt(stats["Silver"])).toString();
                            break;
                        }
                    }
                }
            }

            // ── Tournament list ──────────────────────────────────────────────
            const tournamentList = [];
            // We only want the specific year rows, excluding the Total and Global rows
            allDivs.forEach(div => {
                const text = (div.innerText || '').trim();
                if (/^\\d{4}$/.test(text.split('\\n')[0])) { // Starts with a year
                    tournamentList.push(text.replace(/\\n/g, ' '));
                }
            });

            return { "Summary": stats, "Global Medals": globalMedals, "List": tournamentList };
        }
    """, division_name)

async def extract_rating_history(page):
    """
    Extract player's rating history, including both teams, tournament names, and detailed game scores.
    """
    return await page.evaluate("""
        () => {
            const matches = [];
            const rows = Array.from(document.querySelectorAll('tr'));
            let currentTournament = 'N/A';
            
            rows.forEach(row => {
                const text = row.innerText;
                // Identify Tournament Headers
                if (row.classList.contains('bg-[#333E4F]') || row.classList.contains('bg-gray-800') || (row.cells.length === 1 && (text.includes('PPA') || text.includes('Tournament')))) {
                    currentTournament = text.trim();
                    return;
                }
                
                const cells = Array.from(row.querySelectorAll('td'));
                if (cells.length < 4 || text.includes('Date')) return;

                const match = { 
                    Tournament: currentTournament,
                    Date: 'N/A', 
                    Type: 'N/A', 
                    Team1: [],
                    Team2: [],
                    Score: {
                        Winner: 'N/A',
                        GamesWon: [],
                        GameScores: []
                    }
                };
                
                // 1. Date & Type
                const dateTokens = cells[0].innerText.trim().split(/\\s+/);
                if (dateTokens.length >= 3) {
                    match.Date = dateTokens.slice(0, 3).join(' ');
                    match.Type = dateTokens.slice(3).join(' ') || 'N/A';
                }

                // 2. Score (Middle Column - index 2)
                const scoreText = cells[2].innerText.replace(/\\r?\\n/g, ' ').trim();
                
                if (scoreText.includes('>')) match.Score.Winner = 'Team 1';
                else if (scoreText.includes('<')) match.Score.Winner = 'Team 2';
                
                const gamesWonMatch = scoreText.match(/^(\\d+)\\s+(\\d+)/);
                if (gamesWonMatch) {
                    match.Score.GamesWon = [parseInt(gamesWonMatch[1]), parseInt(gamesWonMatch[2])];
                }
                
                const setScores = scoreText.match(/\\d+\\s*[\\|\\/\\-]\\s*\\d+/g);
                if (setScores) {
                    match.Score.GameScores = setScores.map(s => s.split(/[\\|\\/\\-]/).map(n => parseInt(n.trim())));
                } else {
                    const chunks = scoreText.split(/\\s+/);
                    const possibleScores = chunks.filter(c => /^\\d+$/.test(c));
                    if (possibleScores.length >= 4) { 
                         const actualPoints = possibleScores.slice(2);
                         for (let i = 0; i < actualPoints.length; i += 2) {
                             if (actualPoints[i+1] !== undefined) {
                                 match.Score.GameScores.push([parseInt(actualPoints[i]), parseInt(actualPoints[i+1])]);
                             }
                         }
                    }
                }

                // 3. Teams (Team 1 at index 1, Team 2 at index 3)
                const parseTeam = (cell) => {
                    const players = [];
                    const h3s = Array.from(cell.querySelectorAll('h3'));
                    
                    // Collect all numeric strings in order
                    const ratings = [];
                    const walk = document.createTreeWalker(cell, NodeFilter.SHOW_TEXT, null, false);
                    let node;
                    while(node = walk.nextNode()) {
                        const t = node.textContent.trim();
                        // Match numbers with dots (e.g. 5.766, +0.014) and no letters
                        if (t.length > 0 && /\\d/.test(t) && t.includes('.') && !/[a-zA-Z]/.test(t)) {
                            ratings.push(t);
                        }
                    }

                    // Distribute ratings to players in order
                    const rpp = Math.floor(ratings.length / h3s.length); // Ratings Per Player
                    
                    h3s.forEach((h3, i) => {
                        const block = h3.closest('div.flex-col') || h3.parentElement.parentElement;
                        const info = block.querySelector('p')?.innerText.trim() || 'N/A';
                        const player = { Name: h3.innerText.trim(), Info: info };
                        
                        const start = i * rpp;
                        const playerRatings = ratings.slice(start, start + rpp);
                        
                        if (playerRatings.length >= 3) {
                            player.InitialRating = playerRatings[0];
                            player.RatingChange = playerRatings[1];
                            player.FinalRating = playerRatings[2];
                        } else if (playerRatings.length === 2) {
                            player.InitialRating = playerRatings[0];
                            player.FinalRating = playerRatings[1];
                        } else if (playerRatings.length === 1) {
                            player.Rating = playerRatings[0];
                        }
                        players.push(player);
                    });
                    return players;
                };

                match.Team1 = parseTeam(cells[1]);
                match.Team2 = parseTeam(cells[3]);
                
                if (match.Date !== 'N/A') matches.push(match);
            });
            return matches;
        }
    """)

async def login_pickleball(page, email, password):
    """Handle the login flow on Pickleball.com."""
    print(f"Attempting login to Pickleball.com with {email}...", flush=True)
    
    try:
        await page.goto("https://pickleball.com/", wait_until="domcontentloaded")
        login_btn = page.locator('a[href*="sso.pickleball.com"]').first
        if await login_btn.is_visible(timeout=5000):
            await login_btn.click()
        else:
            await page.goto("https://sso.pickleball.com/?flow=SelfService&continue=https%3A%2F%2Fpickleball.com%2F", wait_until="domcontentloaded")
    except:
        await page.goto("https://sso.pickleball.com/?flow=SelfService&continue=https%3A%2F%2Fpickleball.com%2F", wait_until="domcontentloaded")

    # Step 1: Email
    try:
        selectors = ['#phone_or_email', '#email', 'input[name="identifier"]']
        found = False
        for i in range(20):
            for selector in selectors:
                if await page.locator(selector).is_visible():
                    await page.fill(selector, email)
                    found = True
                    break
            if found: break
            await asyncio.sleep(0.2)
        
        await asyncio.sleep(0.2)
        next_btn = page.locator('button:has-text("Log In"), button:has-text("Continue"), button:has-text("Next"), button[type="submit"]').first
        if await next_btn.is_visible():
            await next_btn.click()
            await asyncio.sleep(2)
    except: pass
    
    # Step 2: Password
    try:
        await page.wait_for_selector('#password', timeout=15000)
        await page.fill('#password', password)
        await asyncio.sleep(1)
        await page.click('button:has-text("Log In"), button[type="submit"]')
    except Exception as e:
        if "sso" not in page.url:
            print("  [OK] Already logged in or bypassed SSO.", flush=True)
            return
        print(f"  [!] Password step issue: {e}", flush=True)

    # Wait for navigation back
    try:
        await page.wait_for_url("**/pickleball.com/**", timeout=30000)
    except: pass
    
    # Handle Passkey / Maybe Later models
    try:
        maybe_later_selectors = ['button:has-text("Maybe Later")', 'div:has-text("Maybe Later")', '#maybe-later']
        for selector in maybe_later_selectors:
            loc = page.locator(selector).first
            if await loc.is_visible(timeout=3000):
                await loc.click()
                print("  [OK] Dismissed 'Maybe Later' modal.", flush=True)
                break
    except: pass
    print("Login sequence completed.", flush=True)

async def wait_for_data(page):
    """Wait for match data rows or 'No matches found' to appear."""
    try:
        # Wait for either a data cell (td) or the "No Matches Found" message
        await page.locator('td, :text("No Matches Found")').first.wait_for(timeout=5000)
        await asyncio.sleep(0.2)
    except:
        await asyncio.sleep(1)

async def scrape_single_player(page, name, worker_id):
    """Scrape a single player's data using the given browser page."""
    candidate_slugs, slug_dupr_map = await resolve_player_slugs(page, name)
    best_history_candidate = None
    max_matches = -1
    player_dupr_id = None

    player_data = {
        "Name": name,
        "URL": f"https://pickleball.com/players/{candidate_slugs[0] if candidate_slugs else ''}",
        "Stats": {},
        "Profile": {},
        "Rating History": []
    }

    # Step A-pre: Get profile first for DUPR ID
    valid_slugs = []
    for url_slug in candidate_slugs:
        stats_url = f"https://pickleball.com/players/{url_slug}/stats"
        try:
            response = await page.goto(stats_url, wait_until="domcontentloaded")
            if page.url == "https://pickleball.com/" or page.url.endswith("/players") or page.url.endswith("/players/"):
                continue
                
            valid_slugs.append(url_slug)
            
            if response and response.status == 200:
                await asyncio.sleep(0.5)
                profile = await extract_profile_info(page)
                if profile.get("DUPR ID") and profile["DUPR ID"] != "N/A":
                    player_dupr_id = profile["DUPR ID"]
                    player_data["Profile"] = profile
                    print(f"  W{worker_id} [{name}] Got DUPR ID {player_dupr_id} from {url_slug}", flush=True)
        except: pass
        
    candidate_slugs = valid_slugs
    if not candidate_slugs:
        print(f"  W{worker_id} [ERR] {name}: No valid profile slugs found.", flush=True)
        return player_data

    # Step A: Identify best history candidate
    for url_slug in candidate_slugs:
        history_url = f"https://pickleball.com/players/{url_slug}/rating-history?current_page=1"
        try:
            await page.goto(history_url, wait_until="domcontentloaded")
            await wait_for_data(page)
            matches = await extract_rating_history(page)
            match_count = len(matches)

            if match_count == 0:
                pagination = page.locator('button:has-text("2"), a:has-text("2"), button:has-text("Next")').first
                if await pagination.is_visible(timeout=3000):
                    await asyncio.sleep(4)
                    matches = await extract_rating_history(page)
                    match_count = len(matches)

            if match_count > 0:
                is_correct_person = True
                if matches and player_data.get("Profile"):
                    profile_age = player_data["Profile"].get("Age", "")
                    recent_match = matches[-1] if len(matches) > 1 else matches[0]
                    name_lower = name.lower()
                    name_parts = name_lower.split()
                    found_player = None
                    for team_key in ["Team1", "Team2"]:
                        for player in recent_match.get(team_key, []):
                            pname = player.get("Name", "").lower()
                            if all(p in pname for p in name_parts):
                                found_player = player
                                break
                        if found_player: break

                    if found_player:
                        info = found_player.get("Info", "")
                        info_parts = info.split("|")
                        if info_parts:
                            match_age = info_parts[0].strip()
                            if profile_age and match_age and profile_age != "N/A" and match_age != "N/A":
                                try:
                                    age_diff = abs(int(match_age) - int(profile_age))
                                    if age_diff > 15:
                                        is_correct_person = False
                                    elif age_diff > 5:
                                        print(f"  W{worker_id} [{name}] Age mismatch warning: {match_age} vs {profile_age}", flush=True)
                                except ValueError: pass

                    if player_dupr_id and slug_dupr_map.get(url_slug):
                        if slug_dupr_map[url_slug] != player_dupr_id:
                            is_correct_person = False

                if is_correct_person and match_count > max_matches:
                    max_matches = match_count
                    best_history_candidate = url_slug
                    break # Break immediately if we found a valid profile with matches
        except: pass

    # Step B: Get stats/profile from best candidate
    best_slug = best_history_candidate or candidate_slugs[0]
    for url_slug in [best_slug]:
        stats_url = f"https://pickleball.com/players/{url_slug}/stats"
        try:
            response = await page.goto(stats_url, wait_until="domcontentloaded")
            if response and response.status == 200:
                await asyncio.sleep(1)
                player_data["Profile"] = await extract_profile_info(page)
                player_data["URL"] = stats_url

                categories = {"Overall": "overall", "PPA Tour": "ppa"}
                divisions = {"Doubles": "doubles", "Mixed": "mixed", "Singles": "singles"}

                for cat_name, cat_param in categories.items():
                    cat_url = f"{stats_url}?show={cat_param}"
                    await page.goto(cat_url, wait_until="domcontentloaded")
                    await asyncio.sleep(0.2)
                    category_data = {
                        "Rankings": await extract_rankings_table(page),
                        "Divisions": {}
                    }
                    for div_name, div_param in divisions.items():
                        div_url = f"{stats_url}?active_filter={div_param}&show={cat_param}"
                        await page.goto(div_url, wait_until="domcontentloaded")
                        await asyncio.sleep(0.2)
                        try:
                            wl_btn = page.locator('button:has-text("win / loss")').first
                            if await wl_btn.is_visible(): await wl_btn.click()
                        except: pass
                        wl_data = await extract_match_stats(page)
                        try:
                            tf_btn = page.locator('button:has-text("titles and finals")').first
                            if await tf_btn.is_visible():
                                await tf_btn.click()
                                await asyncio.sleep(0.2)
                        except: pass
                        tf_data = await extract_titles_finals(page, div_name)
                        category_data["Divisions"][div_name] = {"Match Stats": wl_data, "Titles and Finals": tf_data}
                    player_data["Stats"][cat_name] = category_data
                print(f"  W{worker_id} [{name}] Captured summary from {url_slug}", flush=True)
                break
        except: pass

    # Step C: Scrape full history
    if best_history_candidate:
        all_matches = []
        page_num = 1
        max_pages = 50
        while page_num <= max_pages:
            history_url = f"https://pickleball.com/players/{best_history_candidate}/rating-history?current_page={page_num}"
            try:
                await page.goto(history_url, wait_until="domcontentloaded")
                await wait_for_data(page)
                page_matches = await extract_rating_history(page)
                if not page_matches: break
                all_matches.extend(page_matches)
                next_btn = page.locator('button:has-text("Next"), a:has-text("Next")').first
                if not await next_btn.is_visible() or await next_btn.is_disabled(): break
                page_num += 1
            except: break
        player_data["Rating History"] = all_matches

    print(f"  W{worker_id} [OK] {name} — {len(player_data['Rating History'])} matches", flush=True)
    return player_data


# ── Number of parallel browser tabs ──
NUM_WORKERS = 8

async def scrape_pickleball_profiles(players):
    email = "awansaad6927@gmail.com"
    password = "Parad0x224"
    results = []
    results_lock = asyncio.Lock()
    save_counter = 0

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        context = await browser.new_context(
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        )

        # Login once on a temporary page
        login_page = await context.new_page()
        login_page.set_default_timeout(60000)
        try:
            await login_pickleball(login_page, email, password)
        except Exception as e:
            print(f"Login skip/fail: {e}.", flush=True)
        await login_page.close()

        # Create worker pages
        semaphore = asyncio.Semaphore(NUM_WORKERS)
        pages = []
        for i in range(NUM_WORKERS):
            pg = await context.new_page()
            pg.set_default_timeout(60000)
            pages.append(pg)

        player_queue = asyncio.Queue()
        for name in players:
            await player_queue.put(name)

        async def worker(worker_id, page):
            nonlocal save_counter
            while not player_queue.empty():
                try:
                    name = player_queue.get_nowait()
                except asyncio.QueueEmpty:
                    break
                async with semaphore:
                    try:
                        player_data = await scrape_single_player(page, name, worker_id)
                        async with results_lock:
                            results.append(player_data)
                            save_counter += 1
                            if save_counter % 5 == 0:
                                with open("pickleball_player_stats_v2_partial.json", "w", encoding="utf-8") as f:
                                    json.dump(results, f, indent=4)
                                print(f"  [SAVE] {save_counter}/{len(players)} players saved", flush=True)
                    except Exception as e:
                        print(f"  W{worker_id} [ERR] {name}: {e}", flush=True)

        # Launch workers
        tasks = [asyncio.create_task(worker(i, pages[i])) for i in range(NUM_WORKERS)]
        await asyncio.gather(*tasks)

        for pg in pages:
            await pg.close()
        await browser.close()

    return results

async def main():
    print(f"=== Parallel Pickleball Scraper ({NUM_WORKERS} workers) ===", flush=True)
    print("Fetching active PPA pros from https://ppatour.com/athletes/...", flush=True)
    players = await scrape_ppa_athletes()
    print(f"Found {len(players)} players to scrape.", flush=True)

    if not players:
        print("No players found on PPA athletes page. Aborting.", flush=True)
        return

    import time
    start = time.time()
    final_data = await scrape_pickleball_profiles(players)
    elapsed = time.time() - start

    output_file = "pickleball_player_stats_v2.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(final_data, f, indent=4)

    print(f"\nSuccess! {len(final_data)} players saved to {output_file} in {elapsed/60:.1f} minutes", flush=True)

if __name__ == "__main__":
    asyncio.run(main())
