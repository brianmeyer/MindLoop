import { useState } from "react";
import { HomeScreen } from "./components/screens/HomeScreen";
import { JournalCapture } from "./components/screens/JournalCapture";
import { DecisionSheet } from "./components/screens/DecisionSheet";
import { ExercisePlayer } from "./components/screens/ExercisePlayer";
import { GuidedDeeper } from "./components/screens/GuidedDeeper";
import { GratitudeQuick } from "./components/screens/GratitudeQuick";
import { SessionSummary } from "./components/screens/SessionSummary";
import { SignalsSummary } from "./components/screens/SignalsSummary";
import { SettingsScreen } from "./components/screens/SettingsScreen";
import { JournalHistory, type JournalEntry } from "./components/screens/JournalHistory";

type Screen = 
  | 'home'
  | 'journal'
  | 'history'
  | 'decision'
  | 'exercise'
  | 'deeper'
  | 'gratitude'
  | 'summary'
  | 'settings';

export default function App() {
  const [currentScreen, setCurrentScreen] = useState<Screen>('home');
  const [showSignals, setShowSignals] = useState(false);
  const [journalEntries, setJournalEntries] = useState<JournalEntry[]>([]);
  const [currentTranscript, setCurrentTranscript] = useState('');

  return (
    <div className="size-full bg-background max-w-[390px] mx-auto relative">
      {/* Home Screen */}
      {currentScreen === 'home' && (
        <HomeScreen
          onStartCheckin={() => setCurrentScreen('journal')}
          onQuickGratitude={() => setCurrentScreen('gratitude')}
          onSettings={() => setCurrentScreen('settings')}
          onViewHistory={() => setCurrentScreen('history')}
        />
      )}

      {/* Journal Capture */}
      {currentScreen === 'journal' && (
        <JournalCapture
          onBack={() => setCurrentScreen('home')}
          onComplete={(transcript) => {
            console.log('Journal complete with transcript:', transcript);
            setCurrentTranscript(transcript);
            setShowSignals(true);
          }}
        />
      )}

      {/* Journal History */}
      {currentScreen === 'history' && (
        <JournalHistory
          onBack={() => setCurrentScreen('home')}
          entries={journalEntries}
        />
      )}

      {/* Decision Sheet */}
      {currentScreen === 'decision' && (
        <DecisionSheet
          onBack={() => setCurrentScreen('home')}
          onGoDeeper={() => setCurrentScreen('deeper')}
          onQuickPractice={() => setCurrentScreen('exercise')}
          onSaveForLater={() => {
            // Save the current entry
            const newEntry: JournalEntry = {
              id: Date.now().toString(),
              date: new Date(),
              transcript: currentTranscript,
              valence: 0.3, // Mock data - in real app would come from analysis
              arousal: 0.7,
              emotions: ["Stressed", "Focused", "Determined"],
              topics: ["Work", "Presentation", "Preparation"]
            };
            setJournalEntries(prev => [newEntry, ...prev]);
            setCurrentScreen('home');
          }}
        />
      )}

      {/* Exercise Player */}
      {currentScreen === 'exercise' && (
        <ExercisePlayer
          onBack={() => setCurrentScreen('decision')}
          onComplete={() => setCurrentScreen('summary')}
        />
      )}

      {/* Guided Deeper */}
      {currentScreen === 'deeper' && (
        <GuidedDeeper
          onBack={() => setCurrentScreen('decision')}
          onComplete={() => setCurrentScreen('summary')}
        />
      )}

      {/* Gratitude Quick */}
      {currentScreen === 'gratitude' && (
        <GratitudeQuick
          onBack={() => setCurrentScreen('home')}
          onSave={() => setCurrentScreen('home')}
        />
      )}

      {/* Session Summary */}
      {currentScreen === 'summary' && (
        <SessionSummary
          onDone={() => setCurrentScreen('home')}
          onAddGratitude={() => setCurrentScreen('gratitude')}
        />
      )}

      {/* Settings */}
      {currentScreen === 'settings' && (
        <SettingsScreen onBack={() => setCurrentScreen('home')} />
      )}

      {/* Signals Summary (Modal) */}
      <SignalsSummary
        open={showSignals}
        onClose={() => {
          setShowSignals(false);
          setCurrentScreen('decision');
        }}
      />
    </div>
  );
}
