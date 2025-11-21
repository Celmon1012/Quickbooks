'use client';

import { TrendingUp, TrendingDown } from 'lucide-react';

type GradientVariant = 'purple' | 'blue' | 'yellow' | 'green' | 'white';

interface MetricCardProps {
  title: string;
  value: string | number;
  change?: string | number;
  changeType?: 'increase' | 'decrease' | 'neutral';
  subtitle?: string;
  gradient?: GradientVariant;
  className?: string;
}

const gradientClasses: Record<GradientVariant, string> = {
  purple: 'gradient-purple',
  blue: 'gradient-blue',
  yellow: 'gradient-yellow',
  green: 'gradient-green',
  white: 'bg-white',
};

export default function MetricCard({
  title,
  value,
  change,
  changeType = 'neutral',
  subtitle,
  gradient = 'white',
  className = '',
}: MetricCardProps) {
  const formatValue = (val: string | number): string => {
    if (typeof val === 'number') {
      // Format numbers with commas
      return val.toLocaleString();
    }
    return val;
  };

  const formatChange = (val: string | number): string => {
    if (typeof val === 'number') {
      const sign = val >= 0 ? '+' : '';
      return `${sign}${val}%`;
    }
    return val;
  };

  const getTrendIcon = () => {
    if (changeType === 'increase') {
      return <TrendingUp className="w-4 h-4 text-green-600" />;
    }
    if (changeType === 'decrease') {
      return <TrendingDown className="w-4 h-4 text-red-600" />;
    }
    return null;
  };

  const getTrendColor = () => {
    if (changeType === 'increase') return 'text-green-600';
    if (changeType === 'decrease') return 'text-red-600';
    return 'text-gray-500';
  };

  return (
    <div
      className={`rounded-card-lg p-6 shadow-card hover:shadow-card-hover transition-all ${gradientClasses[gradient]} ${className}`}
    >
      <div className="flex justify-between items-start mb-3">
        <h3 className="text-sm font-medium text-gray-600">{title}</h3>
        {change !== undefined && (
          <div className={`flex items-center gap-1 text-xs ${getTrendColor()}`}>
            {getTrendIcon()}
            <span className="font-medium">{formatChange(change)}</span>
          </div>
        )}
      </div>
      <div className="text-4xl font-bold text-gray-900 mb-2">
        {formatValue(value)}
      </div>
      {subtitle && <div className="text-xs text-gray-500">{subtitle}</div>}
    </div>
  );
}
