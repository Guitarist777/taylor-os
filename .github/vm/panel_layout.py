# Her panel's conversation, as TaylorPanel.places() reports it ("row|dots|list|inrow x y w h"): no two messages overlap, and
# the thinking dots sit inside the list, clear of the typing box and of every other message (her report 2026-11-27).
import sys
rows, other = [], {}
for line in open(sys.argv[1]):
    p = line.split()
    if p and p[0] == "row" and len(p) == 5: rows.append(tuple(map(int, p[1:])))
    elif p and p[0] in ("dots", "list", "inrow") and len(p) == 5: other[p[0]] = tuple(map(int, p[1:]))
L = other.get("list"); D = other.get("dots"); I = other.get("inrow")
vis = sorted(r for r in rows if L and r[1] + r[3] > L[1] and r[1] < L[1] + L[3])
bad = [(a, b) for a, b in zip(vis, vis[1:]) if b[1] < a[1] + a[3] - 1]
print("rows seen", len(vis), "overlapping pairs", len(bad), bad[:3])
if D:
    inside = L and D[1] >= L[1] - 1 and D[1] + D[3] <= L[1] + L[3] + 1
    clear_of_input = I and D[1] + D[3] <= I[1]
    hits = [r for r in vis if D[1] < r[1] + r[3] and r[1] < D[1] + D[3] and not (r[1] <= D[1] and r[1] + r[3] >= D[1] + D[3])]
    print("dots", D, "inside list", bool(inside), "clear of input", bool(clear_of_input), "touching another row", len(hits))
print("PASS" if not bad and D and inside and clear_of_input and not hits else "FAIL")
