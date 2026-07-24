---
name: ai-music-and-audio
description: "Class-level music/audio workflows: songwriting, AI music prompts, MusicGen/AudioGen, Suno-like generation, spectrograms, and Spotify/media support."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Music, Audio, Songwriting, AI-Music, Media]
---

# AI Music and Audio

Use this umbrella when the user asks for song lyrics, AI music prompts, music/audio generation, sound effects, spectrogram analysis, music platform support, YouTube transcript/content transformation, GIF/reaction media lookup, or lightweight media repackaging.

## YouTube and short-form media content

Use YouTube transcript workflows when the user shares a YouTube URL, asks for a transcript, or wants a video transformed into summaries, chapters, threads, quotes, or blog posts. The archived `youtube-content` package contains the transcript helper script and output-format reference; restore/re-home it if exact script behavior is needed.

Use GIF search workflows for Tenor reaction GIF lookup/download when media search is the core task. The archived `gif-search` package contains the Tenor API curl/jq recipes and `TENOR_API_KEY` setup notes.

Use X/Twitter workflows for posting, replying, searching, media uploads, timelines, and DMs when a social-media action is the task. The archived `xurl` package contains the official CLI command reference, OAuth setup rules, and strict secret-safety constraints.

## Songwriting and AI music prompts

For song craft, clarify genre, mood, subject, point of view, structure, vocal style, tempo, and references. Produce lyrics and prompt tags separately when targeting Suno-like systems. Avoid generic AI phrasing; include concrete imagery, singable phrasing, and section labels.

## Audio generation models

Use AudioCraft/MusicGen for text-to-music and AudioGen for text-to-sound when local/model tooling is available. Specify model, duration, prompt, seed if supported, and output path. Verify generated media exists before reporting success.

## Suno-like / HeartMuLa workflows

Use HeartMuLa-style generation when the user provides lyrics plus tags or wants a Suno-like pipeline. Keep lyrics, tags, style prompt, and generation settings distinct so the user can iterate.

## Analysis and media utilities

Use spectrogram/audio-analysis workflows such as Songsee when the user asks to inspect music/audio visually. Use Spotify workflows for playlist/search/playback/library tasks, and YouTube-content workflows for video/channel/transcript/content operations.

## Safety and verification

Respect copyright-sensitive requests: help with style descriptors, original lyrics, and high-level references rather than cloning a living artist exactly. Always return the produced file path/URL or the exact prompt/settings for reproducibility.
