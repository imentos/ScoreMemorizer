# ScoreMemorizer

ScoreMemorizer is an iOS-first acoustic piano practice app built around tempo-based Freeze and Go drills.

## Product Direction

The MVP does not need to display or read a full music sheet. Acoustic piano players already have their sheet or memorized piece in front of them. ScoreMemorizer acts as a coach that interrupts the player on the beat, asks them to freeze, and then brings them back with Go.

The core training question is:

> Can the player stop suddenly, keep their place mentally, and restart in tempo?

## Current MVP

- SwiftUI iPhone/iPad app
- BPM-based metronome
- Time signature setting
- Freeze and Go action words
- Random Freeze prompts on beat boundaries
- Freeze length in bars
- Microphone-based sound activity detection
- Feedback for stopping, staying silent, early starts, and resuming after Go
- Session metrics for Freeze count, early starts, missed stops, and successful resumes

## Why No Sheet In V1

Full sheet rendering, MusicXML position mapping, and acoustic polyphonic note recognition are high-complexity features. V1 focuses on the behavior that matters most for the Freeze and Go concept: interruption recovery.

Without sheet data, the app does not claim to know whether the player resumed on the exact correct chord or measure. Instead it measures the coachable behaviors around the drill:

- Did the player stop after Freeze?
- Did they stay silent during Freeze?
- Did they avoid starting before Go?
- Did they resume close to the Go beat?
- Did they self-report a clean recovery?

## Later

- Add self-rating after each Go: Clean / Almost / Lost
- Add spoken Freeze and Go cues
- Add MusicXML import for score-aware drills
- Add phrase markers or teacher-created drill maps
- Add optional chord/pitch analysis for constrained exercises
