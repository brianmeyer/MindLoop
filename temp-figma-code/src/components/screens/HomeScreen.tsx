import { BookOpen, Heart, Settings, Sparkles } from "lucide-react";
import { MoodSlider } from "../MoodSlider";
import { Button } from "../ui/button";

interface HomeScreenProps {
  onStartCheckin: () => void;
  onQuickGratitude: () => void;
  onSettings: () => void;
  onViewHistory?: () => void;
}

export function HomeScreen({ onStartCheckin, onQuickGratitude, onSettings, onViewHistory }: HomeScreenProps) {
  const greeting = "Good evening, Alex";
  const streak = 7;

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="p-5 flex items-center justify-between border-b border-border">
        <div>
          <h1 className="text-foreground">{greeting}</h1>
          <div className="flex items-center gap-1.5 mt-1">
            <Sparkles className="w-4 h-4 text-[#fbbf24]" />
            <span className="text-muted-foreground">{streak} day streak</span>
          </div>
        </div>
        <div className="flex items-center gap-2">
          {onViewHistory && (
            <button
              onClick={onViewHistory}
              className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
              aria-label="View journal history"
            >
              <BookOpen className="w-5 h-5 text-foreground" />
            </button>
          )}
          <button
            onClick={onSettings}
            className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
            aria-label="Settings"
          >
            <Settings className="w-5 h-5 text-foreground" />
          </button>
        </div>
      </div>

      {/* Main Content */}
      <div className="flex-1 flex flex-col items-center justify-center p-5 space-y-8">
        <div className="w-full max-w-md space-y-6">
          {/* Primary CTA */}
          <div className="text-center space-y-4">
            <p className="text-muted-foreground">Ready for a short check-in?</p>
            <Button
              onClick={onStartCheckin}
              size="lg"
              className="w-full min-h-[56px] rounded-[20px]"
            >
              Start journal
            </Button>
          </div>

          {/* Secondary CTA */}
          <div className="text-center">
            <Button
              onClick={onStartCheckin}
              variant="outline"
              size="lg"
              className="w-full min-h-[56px] rounded-[20px]"
            >
              Quick feeling dump
            </Button>
          </div>

          {/* Quick Mood */}
          <MoodSlider label="How are you feeling?" />

          {/* Gratitude Quick Add */}
          <button
            onClick={onQuickGratitude}
            className="w-full p-4 rounded-[20px] border-2 border-dashed border-border hover:border-[#6ee7b7] transition-colors flex items-center justify-center gap-2 text-muted-foreground hover:text-foreground min-h-[56px]"
          >
            <Heart className="w-5 h-5" />
            <span>Add gratitude</span>
          </button>
        </div>
      </div>
    </div>
  );
}
