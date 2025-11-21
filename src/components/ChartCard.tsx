'use client';

interface ChartCardProps {
  title: string;
  children: React.ReactNode;
  actions?: React.ReactNode;
  className?: string;
}

export default function ChartCard({
  title,
  children,
  actions,
  className = '',
}: ChartCardProps) {
  return (
    <div className={`bg-white rounded-card-lg p-6 shadow-card ${className}`}>
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-lg font-semibold text-gray-900">{title}</h3>
        {actions && <div className="flex gap-2">{actions}</div>}
      </div>
      <div className="w-full h-80">{children}</div>
    </div>
  );
}
