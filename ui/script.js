let currentPage = 1;
const TOTAL_PAGES = 3;

// Ghost trail history for G-Force
const GHOST_MAX = 30;
let ghostTrail = [];

function lerpColor(a, b, amount) { 
    const ah = parseInt(a.replace(/#/g, ''), 16),
        ar = ah >> 16, ag = ah >> 8 & 0xff, ab = ah & 0xff,
        bh = parseInt(b.replace(/#/g, ''), 16),
        br = bh >> 16, bg = bh >> 8 & 0xff, bb = bh & 0xff,
        rr = ar + amount * (br - ar),
        rg = ag + amount * (bg - ag),
        rb = ab + amount * (bb - ab);
    return '#' + ((1 << 24) + (rr << 16) + (rg << 8) + rb | 0).toString(16).slice(1);
}

// Convert temperature to color - Blue (20C) -> Yellow (80C) -> Red (150C)
function getTempColor(temp) {
    if (temp <= 60) {
        let pct = (temp - 20) / 40;
        return lerpColor("#3498db", "#f1c40f", Math.max(0, Math.min(1, pct)));
    } else {
        let pct = (temp - 60) / 90;
        return lerpColor("#f1c40f", "#e74c3c", Math.max(0, Math.min(1, pct)));
    }
}

function updateWheel(id, temp, compress) {
    document.getElementById(`temp-${id}`).innerText = `${Math.round(temp)}°C`;
    document.getElementById(`tire-${id}`).style.background = getTempColor(temp);
    // compress native is 0.0 to approx 0.8. We map to 100% height
    document.getElementById(`susp-${id}`).style.width = `${Math.min(100, Math.max(0, compress * 100))}%`;
}

function renderGhostTrail() {
    const container = document.getElementById('g-force-ghost-container');
    if (!container) return;
    
    // Clear old ghost dots
    container.innerHTML = '';
    
    for (let i = 0; i < ghostTrail.length; i++) {
        const pt = ghostTrail[i];
        const age = i / ghostTrail.length; // 0 = oldest, 1 = newest
        const dot = document.createElement('div');
        dot.className = 'g-ghost-dot';
        dot.style.left = `${pt.x}%`;
        dot.style.top = `${pt.y}%`;
        dot.style.opacity = age * 0.5; // Fade from transparent to semi-visible
        dot.style.width = `${4 + age * 4}px`;
        dot.style.height = `${4 + age * 4}px`;
        container.appendChild(dot);
    }
}

window.addEventListener('message', function(event) {
    let data = event.data;

    if (data.action === "toggle") {
        const container = document.getElementById('telemetry-container');
        if (data.show) {
            container.classList.remove('hidden');
        } else {
            container.classList.add('hidden');
        }
    }

    if (data.action === "cycle") {
        currentPage = currentPage === TOTAL_PAGES ? 1 : currentPage + 1;
        document.getElementById('page-indicator').innerText = `${currentPage} / ${TOTAL_PAGES}`;
        
        document.querySelectorAll('.page').forEach(el => el.classList.add('hidden'));

        if (currentPage === 1) {
            document.getElementById('category-title').innerText = "TIRES & SUSPENSION";
            document.getElementById('page-1').classList.remove('hidden');
        } else if (currentPage === 2) {
            document.getElementById('category-title').innerText = "ENGINE & POWER";
            document.getElementById('page-2').classList.remove('hidden');
        } else if (currentPage === 3) {
            document.getElementById('category-title').innerText = "G-FORCE DYNAMICS";
            document.getElementById('page-3').classList.remove('hidden');
        }
    }

    if (data.action === "update") {
        // Page 1 Updates
        if (currentPage === 1) {
            updateWheel('fl', data.tires[0], data.susp[0]);
            updateWheel('fr', data.tires[1], data.susp[1]);
            updateWheel('rl', data.tires[2], data.susp[2]);
            updateWheel('rr', data.tires[3], data.susp[3]);
            
            document.getElementById('steer-val').innerText = `${data.steerAngle.toFixed(1)}°`;
            
            let wearPct = data.wear * 100;
            document.getElementById('wear-bar').style.width = `${wearPct}%`;
            document.getElementById('wear-val').innerText = `${wearPct.toFixed(1)}%`;
        }

        // Page 2 Updates
        if (currentPage === 2) {
            document.getElementById('gear-val').innerText = data.gear === 0 ? "R" : data.gear;
            document.getElementById('rpm-val').innerText = Math.round(data.rpm * 8000); // Visual mapping
            document.getElementById('speed-val').innerHTML = `${Math.round(data.speed)} <small>MPH</small>`;
            
            document.getElementById('throttle-bar').style.width = `${data.throttle * 100}%`;
            document.getElementById('brake-bar').style.width = `${data.brake * 100}%`;
        }

        // Page 3 Updates — G-Force
        if (currentPage === 3 && data.gForce) {
            let maxG = 1.5;
            let lonG = data.gForce.y; // Forward/Backward
            let latG = data.gForce.x; // Left/Right

            let clampedLonG = Math.max(-maxG, Math.min(maxG, lonG));
            // FIXED: removed the double-negation that was flipping the X axis
            let clampedLatG = Math.max(-maxG, Math.min(maxG, latG));
            
            let latPct = 50 + (clampedLatG / maxG) * 50; 
            let lonPct = 50 + (clampedLonG / maxG) * 50;
            
            document.getElementById('g-force-dot').style.left = `${latPct}%`;
            document.getElementById('g-force-dot').style.top = `${lonPct}%`;
            
            // Push to ghost trail history
            ghostTrail.push({ x: latPct, y: lonPct });
            if (ghostTrail.length > GHOST_MAX) ghostTrail.shift();
            renderGhostTrail();
            
            document.getElementById('g-lat-val').innerText = latG.toFixed(2);
            document.getElementById('g-lon-val').innerText = lonG.toFixed(2);
        }
    }
});
