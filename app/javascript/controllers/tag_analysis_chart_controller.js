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

    const rows = this.dataValue.rows || [];
    if (!rows.length) return;

    const margin = { top: 12, right: 24, bottom: 12, left: 160 };
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

    const x = d3
      .scaleLinear()
      .domain([0, d3.max(rows, (row) => row.value) || 0])
      .nice()
      .range([0, innerWidth]);

    const y = d3
      .scaleBand()
      .domain(rows.map((row) => row.label))
      .range([0, innerHeight])
      .padding(0.24);

    chart
      .append("g")
      .call(
        d3.axisLeft(y)
          .tickSize(0),
      )
      .call((g) => g.select(".domain").remove())
      .call((g) => g.selectAll("text").attr("fill", "#6b7280").attr("font-size", 12));

    chart
      .append("g")
      .attr("transform", `translate(0, ${innerHeight})`)
      .call(
        d3.axisBottom(x)
          .ticks(4)
          .tickFormat((value) => this.#formatAxisValue(value))
          .tickSize(0),
      )
      .call((g) => g.select(".domain").remove())
      .call((g) => g.selectAll("text").attr("fill", "#6b7280").attr("font-size", 12).attr("dy", "1.2em"));

    chart
      .selectAll("rect.bar")
      .data(rows)
      .enter()
      .append("rect")
      .attr("x", 0)
      .attr("y", (row) => y(row.label))
      .attr("width", (row) => x(row.value))
      .attr("height", y.bandwidth())
      .attr("rx", 8)
      .attr("fill", "#0ea5e9");

    chart
      .selectAll("text.value")
      .data(rows)
      .enter()
      .append("text")
      .attr("x", (row) => x(row.value) + 8)
      .attr("y", (row) => y(row.label) + y.bandwidth() / 2)
      .attr("dominant-baseline", "middle")
      .attr("fill", "#94a3b8")
      .attr("font-size", 12)
      .text((row) => this.#formatAxisValue(row.value));
  }

  #formatAxisValue(value) {
    const absolute = Math.abs(value);

    if (absolute >= 1000) {
      return `$${(value / 1000).toFixed(1)}k`;
    }

    return `$${value}`;
  }
}
