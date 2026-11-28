using Toybox.Graphics;
using Toybox.System;

import Toybox.Lang;

// The pages, as the mocks draw them (the Daubenhorn grid: pages 1 to 15, in the owner's order and
// numbers, 2026-11-23, #112), laid out in shares of the screen's width. Pages 16 to 37 follow, one
// issue each (#67 on), in Numbers: so far pages 16 to 19.
module Pages {

    // The pages in the cycle: pages 8 to 11, the stacks, are parked (too noisy, #110) and left out of the
    // app (owner, 2026-11-26, #128): the cycle goes from page 7 to page 12. Their code stays. Pages 16 to
    // 19, the progress in numbers (Numbers, #67), follow page 15; the cycle's last is page 19.
    const COUNT = 15;
    const PARKED_FROM = 7;
    const PARKED = 4;
    // Page 15, the section preview (its place in the cycle), and the section it shows (-1: the climber's).
    const SECTION_PAGE = 10;
    // Page 15's difficulty box: its centre's height and its size; the tap zone beside it uses them too.
    const SECTION_BY = 0.5;
    const SECTION_BW = 0.317308;
    const SECTION_BH = 0.221154;
    var selected as Number = -1;

    // Page 15's words, letter-spaced, measured once: the points' words by their kind (Widgets.POI_WORD),
    // and the dot between them.
    const SEPARATOR = 5;
    var wordWidths as Array<Float?> = new Array<Float?>[6];

    function wordWidth(d as Draw, font as Graphics.FontType, kind as Number) as Float {
        var w = wordWidths[kind];
        if (w == null) {
            w = d.spacedWidth(font, kind == SEPARATOR ? " · " : Widgets.POI_WORD[kind]);
            wordWidths[kind] = w;
        }
        return w;
    }
    const DIM = 0x7f8a8a;

    // The page drawn at a place in the cycle (from 0), counted as Pages.draw's cases: the parked skipped.
    function pageAt(place as Number) as Number {
        return place >= PARKED_FROM ? place + PARKED : place;
    }

    // Draws the page at a place in the cycle.
    function draw(place as Number, d as Draw, st as Climb.State) as Void {
        drawPage(pageAt(place), d, st);
    }

    // Draws a page by its number less 1, the parked ones too (the tests draw every page).
    function drawPage(page as Number, d as Draw, st as Climb.State) as Void {
        d.clear();
        switch (page) {
            // Pages 1 and 2: the profile, and zoomed.
            case 0: { profilePage(d, st, false); break; }
            case 1: { profilePage(d, st, true); break; }
            // Pages 3 and 4: the front view, and zoomed.
            case 2: { frontPage(d, st, false); break; }
            case 3: { frontPage(d, st, true); break; }
            // Page 6: page 5 with the altitudes relative to the current section's bottom.
            case 4: { columnPage(d, st, false); break; }
            case 5: { columnPage(d, st, true); break; }
            case 6: { sideBySide(d, st); break; }
            // Pages 8 and 9 by ascent, 10 and 11 by path; 9 and 11 inside the ascent gauge. Parked: not in
            // the cycle (pageAt skips them, #128).
            case 7: { stackPage(d, st, true, false); break; }
            case 8: { stackPage(d, st, true, true); break; }
            case 9: { stackPage(d, st, false, false); break; }
            case 10: { stackPage(d, st, false, true); break; }
            // Pages 12 and 13: the gauge by length along the route, and by ascent.
            case 11: { gaugePage(d, st, false); break; }
            case 12: { gaugePage(d, st, true); break; }
            case 13: { centrePage(d, st); break; }
            case 14: { sectionPage(d, st); break; }
            // Page 16: the distance, the ascent and the time, done of total (design/page-16.md); pages 17
            // to 19: each alone, large.
            case 15: { Numbers.progress(d, st); break; }
            default: { Numbers.progressOne(d, st, page - 16); break; }
        }
    }

    // ---------------------------------------------------------------- pages 1 and 2: the profile

    // design/page-1.md: profile and ascent share the start and span a rectangle; the altitude group in
    // its upper left, the top of the altitude's digits level with the top of the ascent's top number at
    // the line's end (0.31 of that number's size above the line's end); under the profile the difficulty
    // boxes, 40 % larger than elsewhere, centred on the screen, their tops a box gap below the climber's
    // ring at the start (owner, 2026-11-23). Page 2: the profile zoomed to 100 m of path around the
    // climber, centred in the rectangle, the altitude group on a half-transparent box over it (#102).
    const BOXES_BIG = 1.4;
    // The profile's rectangle: its left, width, bottom and height.
    const PROFILE_X0 = 0.221154;
    const PROFILE_W = 0.625;
    const PROFILE_Y0 = 0.764423;
    const PROFILE_H = 0.543269;

    // The rectangle's left on this route: PROFILE_X0, as in the mock, unless an ascent number's ink would
    // cross the screen's edge from there (Widgets.ascentInset; the Daubenhorn's, #109); then the line,
    // the profile's start and the altitude group move right by whole pixels until it does not, the
    // profile's right end staying (design/page-1.md).
    function profileLeft(d as Draw) as Float {
        return PROFILE_X0 + Widgets.ascentInset(d, PROFILE_X0, PROFILE_Y0, PROFILE_H);
    }

    // Works out page 1's left for the part just put in use, on a bitmap a line high, so the pages' first
    // frame does not: on the real routes that and the frame together tripped the watchdog (#153). A
    // climb's start calls it, in a callback of its own; a change of units still has it worked out on
    // the next frame of page 1.
    function prepare() as Void {
        if (!(Graphics has :createBufferedBitmap)) { return; }
        var w = System.getDeviceSettings().screenWidth;
        var bitmap = Graphics.createBufferedBitmap({:width => w, :height => 1}).get() as Graphics.BufferedBitmap;
        profileLeft(new Draw(bitmap.getDc()));
    }

    function profilePage(d as Draw, st as Climb.State, zoom as Boolean) as Void {
        var x0 = profileLeft(d), w = PROFILE_X0 + PROFILE_W - x0, y0 = PROFILE_Y0, h = PROFILE_H;
        var boxTop = y0 + Widgets.RING_OUTER + Widgets.BOX_GAP;
        var altTop = y0 - h - 0.31 * Widgets.NUMBER_SIZE, ax = x0 + Widgets.RING_OUTER + 0.019231;
        if (zoom) {
            Widgets.profileZoom(d, st, x0, w, y0, h);
        } else {
            Widgets.profile(d, st, x0, w, y0, h);
        }
        Widgets.ascent(d, st, x0, y0, h, true);
        Widgets.difficulty(d, st, 0.5, boxTop, false, BOXES_BIG);
        if (zoom) { Widgets.altitudeGround(d, st, ax, altTop); }
        Widgets.altitudeGroup(d, st, ax, altTop);
    }

    // ---------------------------------------------------------------- pages 5 and 6: the difficulty column

    // design/page-5.md: the difficulty column group, centred, with an altitude at the column's top edge
    // too; page 6 (relative) the altitudes relative to the current section's bottom. On the ferrata as
    // large as fits, 4 % of the width and a pixel from the bezel (Widgets.columnFilled, #160); on the
    // approach at page 7's size, as the HEAD line needs the room.
    function columnPage(d as Draw, st as Climb.State, relative as Boolean) as Void {
        if (Climb.FERRATA) {
            Widgets.columnFilled(d, st, relative);
        } else {
            Widgets.columnGroup(d, st, 0.5, true, relative);
        }
    }

    // ---------------------------------------------------------------- page 7: side by side

    // design/page-7.md: the ascent on the left and the difficulty column group on the right, with equal
    // space before, between and after them across 0.1346 to 0.8654 of the width; the ascent as tall as
    // the column. At the top "NOW" and the current altitude: "NOW" in the altitude's font and size, in
    // the current section's colour (a rest's blue when resting), 0.0288 of the width before the
    // altitude; the line centred as wide as the route's widest altitude, so it never moves.
    function sideBySide(d as Draw, st as Climb.State) as Void {
        var left = 0.134615, right = 0.865385, cy = 0.548077;
        var ascLeft = Widgets.ascentLeft(d), ascW = ascLeft + Widgets.RING_OUTER;
        // Never negative: with wider fonts the widgets would touch rather than overlap.
        var gap = (right - left - ascW - Widgets.columnGroupWidth(d, false)) / 3;
        if (gap < 0) { gap = 0.0; }
        var lx = left + gap + ascLeft, reach = Widgets.columnReach();
        Widgets.ascent(d, st, lx, cy + reach, 2 * reach, true);
        Widgets.columnGroupAt(d, st, lx + Widgets.RING_OUTER + gap, cy, true, false);
        var ft = Widgets.feet(), font = d.semi(Widgets.ALT_SIZE), nowW = d.width(font, "NOW"), nowGap = 0.028846;
        var lineW = nowW + nowGap + Widgets.altitudeBox(d, ft) + 0.009615 + d.width(d.semi(Widgets.ALT_UNIT), ft ? "ft" : "m");
        var x = 0.5 - d.half(lineW), yt = 0.096154, g = Climb.GRADE[st.cur];
        d.textCapTop(x, yt, font, "NOW", g < 0 ? Widgets.REST : d.grade(g, false), Graphics.TEXT_JUSTIFY_LEFT);
        Widgets.altitude(d, st, x + nowW + nowGap, yt);
    }

    // ---------------------------------------------------------------- pages 8 to 11: the stack

    // design/page-8.md, page-10.md: the stack by ascent (byUp: 0.0072 of the width per metre climbed,
    // ticks every 20 m or 100 ft) or by path (0.0024 per metre along the route, ticks every 10 m or 50
    // ft). Without the gauge the window runs from 0.0865 to 0.9135 of the height, within 0.4399 of the
    // centre (6 % of the width clear of the edge); with the ascent gauge around the edge (pages 9, 11)
    // from 0.1538 to 0.8077, within 0.4087, inside the gauge and clear of its numbers. A scale per metre
    // carries nine decimals: it multiplies hundreds of metres.
    function stackPage(d as Draw, st as Climb.State, byUp as Boolean, gauge as Boolean) as Void {
        if (gauge) { Widgets.ascentGauge(d, st, true); }
        Widgets.stack(d, st, byUp, gauge ? 0.153846 : 0.086538, gauge ? 0.807692 : 0.913462,
            byUp ? 0.007211538 : 0.002403846, byUp ? 20 : 10, byUp ? 100 : 50, gauge ? 0.408654 : 0.439904);
    }

    // ---------------------------------------------------------------- pages 12 and 13: the gauge

    // design/page-12.md: the gauge, each section's arc its length along the route (page 12) or the
    // metres it climbs (byUp, page 13); the current difficulty in a large box centred on the screen;
    // above it what comes next, below it the altitude with its unit, and under that the point of
    // interest as a word, all centred (#157; owner, 2026-11-28); on a descent and on the approach the
    // altitude above and what comes next below (Widgets.nextAbove); the ascent along the gauge's gap
    // at the bottom.
    function gaugePage(d as Draw, st as Climb.State, byUp as Boolean) as Void {
        var bw = SECTION_BW, bh = SECTION_BH, by = 0.5;
        Widgets.gauge(d, st, byUp);
        Widgets.bigDifficultyOf(d, Widgets.section(st.cur, false), 0.5, by, bw, bh, 0.1683, Climb.descends(st.cur));
        // The altitude SemiBold 40 px at 416, what comes next Bold 36, GROUP_GAP from the box (owner, 2026-11-23).
        var lines = Widgets.groupLines(by, bh, 0.0962, 0.0865, Widgets.nextAbove(st));
        altitudeLine(d, lines[0], Widgets.altitudeNow(st, Widgets.feet()));
        Widgets.nextUp(d, st, 0.5, lines[1], 0.0865);
        var kind = Widgets.poiNear(st, false);
        if (kind >= 0) {
            d.spaced(0.5, lines[2], d.bold(0.0673), Widgets.POI_WORD[kind], Widgets.POI_COLOUR[kind],
                Graphics.TEXT_JUSTIFY_CENTER);
        }
        Widgets.ascentGap(d, st);
    }

    // An altitude in SemiBold 40 px at 416 and its unit (24), centred on the screen together (owner,
    // 2026-11-23: the number ended at the box's right edge), on the baseline base.
    function altitudeLine(d as Draw, base as Float, v as Number) as Void {
        Widgets.altitudeCentred(d, 0.5, base, v, d.semi(0.0962), d.semi(0.0577), 0.007212);
    }

    // ---------------------------------------------------------------- pages 3 and 4: from the front

    // design/page-3.md: the front view on the right (page 4: zoomed to 100 m of path around the
    // climber, cut on the left 0.0192 of the width right of the group); on the left the current
    // difficulty group, 50 % larger as on pages 12, 13, 14 and 15, its box centred vertically on the
    // screen, as far left as the round screen allows (Widgets.groupPlace; owner, 2026-11-23).
    const FRONT_GROUP = 1.5;

    function frontPage(d as Draw, st as Climb.State, zoom as Boolean) as Void {
        var place = Widgets.groupPlace(d, 0.5, FRONT_GROUP);
        if (zoom) {
            Widgets.frontZoom(d, st, 0.442308, 0.884615, 0.153846, 0.846154, place[1] + Widgets.GROUP_MARGIN);
        } else {
            Widgets.frontView(d, st, 0.442308, 0.884615, 0.153846, 0.846154);
        }
        Widgets.group(d, st, place[0], 0.5, FRONT_GROUP, false, false);
    }

    // ---------------------------------------------------------------- page 14: the centre

    // design/page-14.md: the current difficulty group in the middle, 50 % larger, what comes next above
    // the box and the altitude below it as on pages 12 and 13 (#157), with the point of interest as a
    // word under it; the ascent as a gauge around the edge.
    function centrePage(d as Draw, st as Climb.State) as Void {
        Widgets.ascentGauge(d, st, true);
        Widgets.group(d, st, 0.5, 0.5, 1.5, true, true);
    }

    // ---------------------------------------------------------------- page 15: a section preview

    // Page 15's altitudes, [above the box, below it], to the metre or foot: a climb's end above and its
    // start below, up the stack; a descent, whose trapezium already says it goes down, its start (the
    // higher) above and its end below (#100; owner, 2026-11-23).
    function sectionLines(i as Number, ft as Boolean) as [Number, Number] {
        var a = Widgets.sectionAltitudes(i, ft);
        return Climb.descends(i) ? [a[0], a[1]] : [a[1], a[0]];
    }

    // design/page-15.md: page 13's gauge showing the selected section (the climber's until the user
    // steps), its difficulty in the middle between chevrons (a trapezium for a descent), its altitudes
    // above and below (sectionLines), under them its points as words, a dim dot between; the ascent
    // along the gauge's gap shows the climber.
    function sectionPage(d as Draw, st as Climb.State) as Void {
        var i = selected >= 0 ? selected : st.cur, n = Climb.count();
        var bw = SECTION_BW, bh = SECTION_BH, by = SECTION_BY;
        Widgets.selectionGauge(d, i);
        Widgets.bigDifficultyOf(d, Widgets.section(i, false), 0.5, by, bw, bh, 0.1683, Climb.descends(i));
        Widgets.chevron(d, 0.5 - bw / 2 - 0.096154, by, -1, i > 0);
        Widgets.chevron(d, 0.5 + bw / 2 + 0.096154, by, 1, i < n - 1);
        var alts = sectionLines(i, Widgets.feet());
        var footBase = by + bh / 2 + Widgets.GROUP_GAP + 0.7 * 0.0962;
        altitudeLine(d, by - bh / 2 - Widgets.GROUP_GAP, alts[0]);
        altitudeLine(d, footBase, alts[1]);
        // The points, Bold 28 px at 416, letter-spaced, each in its colour, centred as one line.
        var kinds = Widgets.sectionPoints(i);
        if (kinds.size() > 0) {
            var font = d.bold(0.0673), total = 0.0;
            for (var p = 0; p < kinds.size(); p++) {
                if (p > 0) { total += wordWidth(d, font, SEPARATOR); }
                total += wordWidth(d, font, kinds[p]);
            }
            var px = 0.5 - total / 2, base = footBase + 0.028846 + 0.7 * 0.0673;
            for (var p = 0; p < kinds.size(); p++) {
                if (p > 0) {
                    d.spaced(px, base, font, " · ", DIM, Graphics.TEXT_JUSTIFY_LEFT);
                    px += wordWidth(d, font, SEPARATOR);
                }
                d.spaced(px, base, font, Widgets.POI_WORD[kinds[p]], Widgets.POI_COLOUR[kinds[p]], Graphics.TEXT_JUSTIFY_LEFT);
                px += wordWidth(d, font, kinds[p]);
            }
        }
        Widgets.ascentGap(d, st);
    }
}
