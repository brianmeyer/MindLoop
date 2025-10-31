import { Badge } from "./ui/badge";
import { cn } from "./ui/utils";

interface DecisionCardProps {
  title: string;
  description: string;
  badge?: string;
  onClick: () => void;
  variant?: 'primary' | 'secondary';
}

export function DecisionCard({ title, description, badge, onClick, variant = 'secondary' }: DecisionCardProps) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "w-full text-left p-6 rounded-[20px] border-2 transition-all active:scale-[0.98]",
        variant === 'primary' 
          ? "bg-primary text-primary-foreground border-primary shadow-lg" 
          : "bg-card border-border hover:border-primary/20"
      )}
    >
      <div className="flex items-start justify-between gap-3 mb-2">
        <h3 className={variant === 'primary' ? 'text-primary-foreground' : 'text-foreground'}>
          {title}
        </h3>
        {badge && (
          <Badge variant="secondary" className="shrink-0">
            {badge}
          </Badge>
        )}
      </div>
      <p className={cn(
        variant === 'primary' ? 'text-primary-foreground/80' : 'text-muted-foreground'
      )}>
        {description}
      </p>
    </button>
  );
}
