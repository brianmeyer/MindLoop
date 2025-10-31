import { ArrowLeft, Calendar } from "lucide-react";
import { Badge } from "../ui/badge";
import { Card } from "../ui/card";
import { ScrollArea } from "../ui/scroll-area";
import { ValenceGauge } from "../ValenceGauge";
import { ArousalBar } from "../ArousalBar";

export interface JournalEntry {
  id: string;
  date: Date;
  transcript: string;
  valence: number;
  arousal: number;
  emotions: string[];
  topics: string[];
}

interface JournalHistoryProps {
  onBack: () => void;
  entries: JournalEntry[];
  onEntryClick?: (entry: JournalEntry) => void;
}

export function JournalHistory({ onBack, entries, onEntryClick }: JournalHistoryProps) {
  const formatDate = (date: Date) => {
    const now = new Date();
    const diff = now.getTime() - date.getTime();
    const days = Math.floor(diff / (1000 * 60 * 60 * 24));
    
    if (days === 0) return "Today";
    if (days === 1) return "Yesterday";
    if (days < 7) return `${days} days ago`;
    
    return date.toLocaleDateString('en-US', { 
      month: 'short', 
      day: 'numeric',
      year: date.getFullYear() !== now.getFullYear() ? 'numeric' : undefined
    });
  };

  const formatTime = (date: Date) => {
    return date.toLocaleTimeString('en-US', { 
      hour: 'numeric', 
      minute: '2-digit',
      hour12: true 
    });
  };

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Header */}
      <div className="p-5 flex items-center gap-4 border-b border-border">
        <button
          onClick={onBack}
          className="w-10 h-10 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform"
          aria-label="Go back"
        >
          <ArrowLeft className="w-5 h-5" />
        </button>
        <h2 className="text-foreground">Your Journal</h2>
      </div>

      {/* Entries List */}
      <ScrollArea className="flex-1">
        <div className="p-5 space-y-4">
          {entries.length === 0 ? (
            <div className="text-center py-12 space-y-2">
              <Calendar className="w-12 h-12 mx-auto text-muted-foreground opacity-50" />
              <p className="text-muted-foreground">No journal entries yet</p>
              <p className="text-muted-foreground">Start your first check-in to begin</p>
            </div>
          ) : (
            entries.map((entry) => (
              <Card
                key={entry.id}
                className="p-4 space-y-3 cursor-pointer active:scale-[0.98] transition-transform"
                onClick={() => onEntryClick?.(entry)}
              >
                {/* Date & Time */}
                <div className="flex items-center justify-between">
                  <span className="text-muted-foreground">
                    {formatDate(entry.date)}
                  </span>
                  <span className="text-muted-foreground">
                    {formatTime(entry.date)}
                  </span>
                </div>

                {/* Transcript Preview */}
                <p className="text-foreground line-clamp-3">
                  {entry.transcript || "No transcript available"}
                </p>

                {/* Emotions & Topics */}
                <div className="space-y-2">
                  {entry.emotions.length > 0 && (
                    <div className="flex flex-wrap gap-2">
                      {entry.emotions.map((emotion, i) => (
                        <Badge key={i} variant="secondary" className="rounded-full">
                          {emotion}
                        </Badge>
                      ))}
                    </div>
                  )}
                  {entry.topics.length > 0 && (
                    <div className="flex flex-wrap gap-2">
                      {entry.topics.map((topic, i) => (
                        <Badge key={i} variant="outline" className="rounded-full">
                          {topic}
                        </Badge>
                      ))}
                    </div>
                  )}
                </div>

                {/* Emotional indicators - compact */}
                <div className="grid grid-cols-2 gap-3 pt-2">
                  <div className="space-y-1">
                    <div className="text-muted-foreground">Tone</div>
                    <ValenceGauge value={entry.valence} compact />
                  </div>
                  <div className="space-y-1">
                    <div className="text-muted-foreground">Energy</div>
                    <ArousalBar value={entry.arousal} compact />
                  </div>
                </div>
              </Card>
            ))
          )}
        </div>
      </ScrollArea>
    </div>
  );
}
