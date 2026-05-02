import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

export default class extends Controller {
  static values = {
    data: Object,
  };

  connect() {
    this.render();
    this.resizeObserver = new ResizeObserver(() => this.render());
    this.resizeObserver.observe(this.element);
  }

  disconnect() {
    this.resizeObserver?.disconnect();
  }

  render() {
    const width = this.element.clientWidth;
    const height = 320;

    if (!width) return;

    d3.select(this.element).selectAll("*").remove();

    const data = this.dataValue.values || [];
    if (!data.length) return;

    const margin = { top: 20, right: 20, bottom: 48, left: 56 };
    const innerWidth = width - margin.left - margin.right;
    const innerHeight = height - margin.top - margin.bottom;

    const svg = d3
      .select(this.element)
      .append("svg")
      .attr("viewBox", `0 0 ${width} ${height}`)
      .attr("preserveAspectRatio", "xMidYMid meet")
      .attr("class", "h-full w-full");

    const chart = svg
      .append("g")
      .attr("transform", `translate(${margin.left}, ${margin.top})`);

    const x0 = d3
      .scaleBand()
      .domain(data.map((d) => d.label))
      .range([0, innerWidth])
      .padding(0.24);

    const x1 = d3
      .scaleBand()
      .domain(["income", "expense"])
      .range([0, x0.bandwidth()])
      .padding(0.18);

    const maxValue = d3.max(data, (d) => Math.max(d.income, d.expense, 0)) || 0;

    const y = d3
      .scaleLinear()
      .domain([0, maxValue])
      .nice()
      .range([innerHeight, 0]);

    chart
      .append("g")
      .call(
        d3.axisLeft(y)
          .ticks(5)
          .tickFormat((value) => this.#formatAxisValue(value)),
      )
      .call((g) => g.select(".domain").remove())
      .call((g) => g.selectAll(".tick line").attr("stroke", "#d7dee7"))
      .call((g) => g.selectAll(".tick text").attr("fill", "#6b7280").attr("font-size", 12));

    chart
      .append("line")
      .attr("x1", 0)
      .attr("x2", innerWidth)
      .attr("y1", y(0))
      .attr("y2", y(0))
      .attr("stroke", "#cfd8e3");

    const group = chart
      .selectAll("g.bar-group")
      .data(data)
      .enter()
      .append("g")
      .attr("transform", (d) => `translate(${x0(d.label)}, 0)`);

    group
      .selectAll("rect")
      .data((d) => [
        { key: "income", value: d.income, color: "#16a34a" },
        { key: "expense", value: d.expense, color: "#ef4444" },
      ])
      .enter()
      .append("rect")
      .attr("x", (d) => x1(d.key))
      .attr("y", (d) => y(d.value))
      .attr("width", x1.bandwidth())
      .attr("height", (d) => y(0) - y(d.value))
      .attr("rx", 6)
      .attr("fill", (d) => d.color);

    chart
      .append("g")
      .attr("transform", `translate(0, ${innerHeight})`)
      .call(
        d3.axisBottom(x0)
          .tickValues(this.#visibleTicks(data))
          .tickSize(0),
      )
      .call((g) => g.select(".domain").remove())
      .call((g) => g.selectAll("text").attr("fill", "#6b7280").attr("font-size", 12))
      .call((g) => g.selectAll("text").attr("dy", "1.2em"));

    const legend = svg
      .append("g")
      .attr("transform", `translate(${margin.left}, ${height - 12})`);

    const legendPayload = this.dataValue.legend || {};
    const legendItems = [
      { label: legendPayload.income || "Income", color: "#16a34a" },
      { label: legendPayload.expenses || "Expenses", color: "#ef4444" }
    ];

    legendItems.forEach((item, index) => {
      const entry = legend.append("g").attr("transform", `translate(${index * 132}, 0)`);

      entry.append("rect")
        .attr("width", 18)
        .attr("height", 10)
        .attr("rx", 3)
        .attr("y", -9)
        .attr("fill", item.color);

      entry.append("text")
        .attr("x", 24)
        .attr("y", 0)
        .attr("fill", "#6b7280")
        .attr("font-size", 12)
        .text(item.label);
    });
  }

  #visibleTicks(data) {
    if (data.length <= 6) return data.map((d) => d.label);

    return data
      .filter((_, index) => index % 2 === 0 || index === data.length - 1)
      .map((d) => d.label);
  }

  #formatAxisValue(value) {
    const absolute = Math.abs(value);

    if (absolute >= 1000) {
      return `$${(value / 1000).toFixed(1)}k`;
    }

    return `$${value}`;
  }
}
