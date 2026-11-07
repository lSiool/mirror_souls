[CHARACTER]
{PREFIX} {SUBJECT}
SUBJECT: full-body game character, {name/role}, {key costume details}, holding {item}.
POSE: neutral side 3/4 view for a 2.5D side-scroller, readable silhouette, whole figure visible.
OUTPUT: centered, plain flat neutral grey background, no shadow on ground, consistent with attached reference images.
{AVOID}

[ENVIRONMENT]
{PREFIX} {SCENE}
SCENE: {location}, {time/mood}, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level,
clear walkable ground line in lower third, foreground framing elements, far background fades into fog.
FOCUS: {key object} as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}

[ENVIRONMENT TIERED]
{PREFIX} {WORLD}
SCENE: {location}, {time/mood}, wide 16:9 side-view composition for a 2.5D platformer, camera slightly above eye level,
{N} clearly separated walkable levels: {lower level}, {connection between levels}, {upper level},
every walkable surface lit brighter than the wall behind it, far background fades into fog.
FOCUS: {key object} as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}

[KEY ART]
{PREFIX} {SCENE}
SCENE: {location}, {time/mood}, cinematic wide 16:9 one-point perspective, {who is looking}, monumental scale.
FOCUS: {key object} as the brightest point of the image.
OUTPUT: consistent with attached reference images.
{AVOID}

[PROP]
{PREFIX} {OBJECT}
OBJECT: {item}, {material and wear}, 3/4 view, isolated, plain flat neutral grey background,
soft cold rim light from upper left, no cast shadow.
{AVOID}

[UI ICON]
{PREFIX} {ICON}
ICON: {item/ability}, single bold silhouette centered on a 1:1 canvas, readable at 64 px,
dark vignette circle behind, flat grey outside the circle, minimal detail, no text.
{AVOID}

## SAMPLE
{PREFIX} {WORLD_MIRROR}
OBJECT: an ornate standing mirror-portal in a tarnished bronze gothic frame, the glass cracked into a spiderweb
from the center, several shards floating outward and catching pale teal light from another world visible inside
the cracks, mercury backing peeling at the edges. 3/4 view, isolated, plain flat neutral grey background,
cold rim light from upper left, no cast shadow, consistent with attached reference images.
{AVOID}
