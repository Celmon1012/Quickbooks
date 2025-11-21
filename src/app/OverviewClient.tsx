'use client';

import {
  DashboardHeader,
  MetricCard,
  ChartCard,
  DataTable,
  LineChart,
  BarChart,
  DonutChart,
} from '@/components';

interface OverviewClientProps {
  companyName: string;
  lastSyncAt: string | null;
  metrics: {
    revenue: { value: string; change: number };
    netIncome: { value: string; change: number };
    opex: { value: string; change: number };
    grossMargin: { value: string; change: number };
  };
  lineChartData: Array<{ month: string; revenue: number; expenses: number }>;
  barChartData: Array<{ month: string; operating: number; investing: number; financing: number }>;
  donutChartData: Array<{ name: string; value: number }>;
  tableData: Array<{ date: string; description: string; amount: string; category: string }>;
  kpiMetrics: {
    grossMargin: string;
    netMargin: string;
    operatingCashFlow: string;
    revenueGrowth: string;
  };
}

const tableColumns = [
  { key: 'date', label: 'Date', sortable: true },
  { key: 'description', label: 'Description', sortable: false },
  { key: 'amount', label: 'Amount', sortable: true },
  { key: 'category', label: 'Category', sortable: true },
];

export default function OverviewClient({
  companyName,
  lastSyncAt,
  metrics,
  lineChartData,
  barChartData,
  donutChartData,
  tableData,
  kpiMetrics,
}: OverviewClientProps) {
  const handleRefresh = () => {
    // Trigger page refresh to fetch latest data
    window.location.reload();
  };

  const handleFilter = () => {
    // TODO: Implement filter functionality
    console.log('Filter clicked');
  };

  return (
    <>
      <DashboardHeader
        userName={companyName}
        userRole="Finance Manager"
        lastSyncAt={lastSyncAt ? new Date(lastSyncAt) : null}
        onRefresh={handleRefresh}
        onFilter={handleFilter}
      />

      {/* Metrics Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mb-8">
        <MetricCard
          title="Total Revenue"
          value={metrics.revenue.value}
          change={metrics.revenue.change}
          changeType={metrics.revenue.change >= 0 ? 'increase' : 'decrease'}
          subtitle="vs last month"
          gradient="purple"
        />
        <MetricCard
          title="Net Income"
          value={metrics.netIncome.value}
          change={metrics.netIncome.change}
          changeType={metrics.netIncome.change >= 0 ? 'increase' : 'decrease'}
          subtitle="vs last month"
          gradient="blue"
        />
        <MetricCard
          title="Operating Expenses"
          value={metrics.opex.value}
          change={metrics.opex.change}
          changeType={metrics.opex.change <= 0 ? 'increase' : 'decrease'}
          subtitle="vs last month"
          gradient="yellow"
        />
        <MetricCard
          title="Gross Margin"
          value={metrics.grossMargin.value}
          change={metrics.grossMargin.change}
          changeType={metrics.grossMargin.change >= 0 ? 'increase' : 'decrease'}
          subtitle="vs last month"
          gradient="green"
        />
      </div>

      {/* Charts Section */}
      {lineChartData.length > 0 && barChartData.length > 0 && (
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
          <ChartCard title="Revenue vs Expenses">
            <LineChart
              data={lineChartData}
              lines={[
                { dataKey: 'revenue', stroke: '#8b5cf6', name: 'Revenue' },
                { dataKey: 'expenses', stroke: '#60a5fa', name: 'Expenses' },
              ]}
              xAxisKey="month"
            />
          </ChartCard>

          <ChartCard title="Cash Flow Breakdown">
            <BarChart
              data={barChartData}
              bars={[
                { dataKey: 'operating', fill: '#10b981', name: 'Operating' },
                { dataKey: 'investing', fill: '#f59e0b', name: 'Investing' },
                { dataKey: 'financing', fill: '#8b5cf6', name: 'Financing' },
              ]}
              xAxisKey="month"
              stacked
            />
          </ChartCard>
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 mb-8">
        {donutChartData.length > 0 && (
          <ChartCard title="Expense Distribution">
            <DonutChart
              data={donutChartData}
              colors={['#8b5cf6', '#60a5fa', '#f59e0b', '#10b981']}
            />
          </ChartCard>
        )}

        <div className="bg-white rounded-card-lg p-6 shadow-card">
          <h3 className="text-lg font-semibold text-gray-900 mb-4">Key Metrics</h3>
          <div className="space-y-4">
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Gross Profit Margin</span>
              <span className="text-lg font-semibold text-gray-900">{kpiMetrics.grossMargin}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Net Profit Margin</span>
              <span className="text-lg font-semibold text-gray-900">{kpiMetrics.netMargin}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Operating Cash Flow</span>
              <span className="text-lg font-semibold text-gray-900">{kpiMetrics.operatingCashFlow}</span>
            </div>
            <div className="flex justify-between items-center">
              <span className="text-sm text-gray-600">Revenue Growth</span>
              <span className={`text-lg font-semibold ${
                kpiMetrics.revenueGrowth.startsWith('-') ? 'text-red-600' : 'text-green-600'
              }`}>
                {kpiMetrics.revenueGrowth.startsWith('-') ? '' : '+'}{kpiMetrics.revenueGrowth}
              </span>
            </div>
          </div>
        </div>
      </div>

      {/* Recent Transactions Table */}
      {tableData.length > 0 && (
        <DataTable
          title="Recent Transactions"
          columns={tableColumns}
          data={tableData}
          onViewAll={() => console.log('View all clicked')}
          pageSize={5}
        />
      )}

      {/* No data message */}
      {lineChartData.length === 0 && barChartData.length === 0 && tableData.length === 0 && (
        <div className="bg-white rounded-card-lg p-12 shadow-card text-center">
          <h3 className="text-lg font-semibold text-gray-900 mb-2">No Data Available</h3>
          <p className="text-gray-600">
            No financial data found. Please sync your QuickBooks Online data to see your dashboard.
          </p>
        </div>
      )}
    </>
  );
}
