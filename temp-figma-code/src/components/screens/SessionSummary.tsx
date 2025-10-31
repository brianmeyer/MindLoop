import { Heart, ThumbsUp, ThumbsDown, Minus } from "lucide-react";
import { Button } from "../ui/button";
import { Badge } from "../ui/badge";

interface SessionSummaryProps {
  onDone: () => void;
  onAddGratitude: () => void;
}

export function SessionSummary({ onDone, onAddGratitude }: SessionSummaryProps) {
  const reflection = "I notice I'm worried about tomorrow's presentation, but I have prepared well.";
  const tags = ["Work stress", "Anxiety", "Preparation"];
  const suggestions = ["Take a 5-min break", "Review notes once", "Early bedtime"];

  return (
    <div className="min-h-screen bg-background flex flex-col">
      {/* Main Content */}
      <div className="flex-1 p-5 space-y-8 pt-12">
        <div className="max-w-md mx-auto w-full space-y-8">
          {/* Header */}
          <div className="text-center space-y-2">
            <div className="inline-flex items-center justify-center w-14 h-14 rounded-full bg-[#7bb8e7]/20 mb-2">
              <ThumbsUp className="w-7 h-7 text-[#2563eb]" />
            </div>
            <h2 className="text-foreground">Nice work</h2>
            <p className="text-muted-foreground">Here's what we captured</p>
          </div>

          {/* Reflection */}
          <div className="bg-card border border-border rounded-[20px] p-6 space-y-4">
            <h3 className="text-foreground">Your reflection</h3>
            <p className="text-muted-foreground leading-relaxed">{reflection}</p>
          </div>

          {/* Tags */}
          <div className="space-y-3">
            <h4 className="text-muted-foreground">Themes</h4>
            <div className="flex flex-wrap gap-2">
              {tags.map((tag, i) => (
                <Badge key={i} variant="secondary" className="rounded-full">
                  {tag}
                </Badge>
              ))}
            </div>
          </div>

          {/* Next Steps */}
          <div className="space-y-3">
            <h4 className="text-foreground">One small step for tomorrow?</h4>
            <div className="space-y-2">
              {suggestions.map((suggestion, i) => (
                <button
                  key={i}
                  className="w-full text-left p-4 rounded-[20px] border border-border hover:border-primary/20 transition-colors active:scale-[0.98]"
                >
                  {suggestion}
                </button>
              ))}
            </div>
          </div>

          {/* Gratitude Link */}
          <button
            onClick={onAddGratitude}
            className="w-full p-4 rounded-[20px] border-2 border-dashed border-border hover:border-[#6ee7b7] transition-colors flex items-center justify-center gap-2 text-muted-foreground hover:text-foreground min-h-[56px]"
          >
            <Heart className="w-5 h-5" />
            <span>Add gratitude</span>
          </button>

          {/* Helpfulness */}
          <div className="space-y-3">
            <p className="text-center text-muted-foreground">Was this helpful?</p>
            <div className="flex items-center justify-center gap-3">
              <button className="w-12 h-12 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform">
                <ThumbsUp className="w-5 h-5" />
              </button>
              <button className="w-12 h-12 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform">
                <Minus className="w-5 h-5" />
              </button>
              <button className="w-12 h-12 rounded-full bg-muted flex items-center justify-center active:scale-95 transition-transform">
                <ThumbsDown className="w-5 h-5" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Actions */}
      <div className="p-5 border-t border-border">
        <div className="max-w-md mx-auto">
          <Button
            onClick={onDone}
            size="lg"
            className="w-full min-h-[56px] rounded-[20px]"
          >
            Done
          </Button>
        </div>
      </div>
    </div>
  );
}
