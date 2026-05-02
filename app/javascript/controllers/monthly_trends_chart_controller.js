import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

const parseLocalDate = d3.timeParse("%Y-%m-%d");

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

    const series = (this.dataValue.series || []).map((item) => ({
      ...item,
      values: (item.values || []).map((point) => ({
        ...point,
        date: parseLocalDate(point.date),
      })),
    }));

    const allValues = series.flatMap((item) => item.values);
    if (!allValues.length) return;

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

    const x = d3
      .scaleTime()
      .domain(d3.extent(allValues, (d) => d.date))
      .range([0, innerWidth]);

    const y = d3
      .scaleLinear()
      .domain([0, d3.max(allValues, (d) => d.value) || 0])
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
      .append("g")
      .attr("transform", `translate(0, ${innerHeight})`)
      .call(
        d3.axisBottom(x)
          .ticks(Math.min(series[0].values.length, width < 640 ? 4 : 6))
          .tickFormat(d3.timeFormat("%b %Y"))
          .tickSize(0),
      )
      .call((g) => g.select(".domain").remove())
      .call((g) => g.selectAll("text").attr("fill", "#6b7280").attr("font-size", 12).attr("dy", "1.2em"));

    const line = d3.line()
      .x((d) => x(d.date))
      .y((d) => y(d.value))
      .curve(d3.curveMonotoneX);

    series.forEach((item) => {
      chart
        .append("path")
        .datum(item.values)
        .attr("fill", "none")
        .attr("stroke", item.color)
        .attr("stroke-width", item.dashed ? 2 : 2.5)
        .attr("stroke-dasharray", item.dashed ? "6 6" : null)
        .attr("stroke-linejoin", "round")
        .attr("stroke-linecap", "round")
        .attr("d", line);
    });

    const legend = svg
      .append("g")
      .attr("transform", `translate(${margin.left}, ${height - 12})`);

    series.forEach((item, index) => {
      const entry = legend.append("g").attr("transform", `translate(${index * 160}, 0)`);

      entry.append("line")
        .attr("x1", 0)
        .attr("x2", 18)
        .attr("y1", -4)
        .attr("y2", -4)
        .attr("stroke", item.color)
        .attr("stroke-width", item.dashed ? 2 : 2.5)
        .attr("stroke-dasharray", item.dashed ? "6 6" : null);

      entry.append("text")
        .attr("x", 24)
        .attr("y", 0)
        .attr("fill", "#6b7280")
        .attr("font-size", 12)
        .text(item.label);
    });
  }

  #formatAxisValue(value) {
    const absolute = Math.abs(value);

    if (absolute >= 1000) {
      return `$${(value / 1000).toFixed(1)}k`;
    }

    return `$${value}`;
  }
}
