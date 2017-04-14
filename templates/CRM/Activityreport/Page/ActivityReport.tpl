<h3>Activity Pivot Table</h3>

<div id="activity-report-preloader">
  Loading <span id="activity-report-loading-count">0</span> of <span id="activity-report-loading-total">0</span> Activities.
</div>
<div id="activity-report-filters" class="hidden">
  <form>
    <label for="activity_start_date">Activity start date</label>
    <input type="text" name="activity_start_date" value="">
    <input type="button" value="Apply filters">
  </form>
</div>
<div id="report-pivot-table">
</div>

{literal}
<script type="text/javascript">
    // Handle jQuery prop() method if it's not supported.
    (function($){
        if (typeof $.fn.prop !== 'function')
        $.fn.prop = function(name, value){
            if (typeof value === 'undefined') {
                return this.attr(name);
            } else {
                return this.attr(name, value);
            }
        };
    })(jQuery);
    CRM.$(function () {
        var data = [];
        var limit = 1000;

        /**
         * Load a pack of Activities data. If there is more data to load
         * (depending on the total value and the response) then we run
         * the function recursively.
         *
         * @param int offset
         *   Offset to start with (initially should be 0)
         * @param int limit
         *   Limit of data to load with one call
         * @param int total
         *   Helper parameter telling us if we need to keep loading the data
         * @param int multiValuesOffset
         *   In case we are in the middle of a multivalues activity,
         *   we know the combination to start with another call.
         * @param int multiValuesTotal
         *   In case we are in the middle of a multivalues activity,
         *   we know the total number of multivalues combinations for
         *   this particular Activity
         */
        function loadData(offset, limit, total, multiValuesOffset, multiValuesTotal) {
          CRM.$('span#activity-report-loading-count').text(offset);
          var localLimit = limit;

          if (multiValuesOffset > 0 && multiValuesTotal > 0) {
            localLimit = limit - (multiValuesTotal - multiValuesOffset);
          }
          if (multiValuesTotal - multiValuesOffset > limit) {
            localLimit = 1;
          }
          if (offset + localLimit > total) {
            localLimit = total - offset;
          }

          CRM.api3('ActivityReport', 'get', {
            "sequential": 1,
            "offset": offset,
            "limit": localLimit,
            "multiValuesOffset": multiValuesOffset
          }).done(function(result) {
            data = data.concat(processData(result['values'][0].data));
            var nextOffset = parseInt(result['values'][0].info.nextOffset, 10);

            if (nextOffset > total) {
              loadComplete(data);
            } else {
              var multiValuesOffset = parseInt(result['values'][0]['info'].multiValuesOffset, 10);
              var multiValuesTotal = parseInt(result['values'][0]['info'].multiValuesTotal, 10);
              loadData(nextOffset, limit, total, multiValuesOffset, multiValuesTotal);
            }
          });
        }

        function loadComplete(data) {
          CRM.$('#activity-report-preloader').addClass('hidden');
          CRM.$('#activity-report-filters').removeClass('hidden');
          initPivotTable(data);
        }

        /**
         * Format incoming data (combine header with fields values)
         * to be compatible with Pivot library.
         *
         * @param array data
         * @returns array
         */
        function processData(data) {
          var result = [];
          var i, j;
          var header = data[0];

          delete data[0];

          for (i in data) {
            var row = {};
            for (j in data[i]) {
              row[header[j]] = data[i][j];
            }
            result.push(row);
          }

          return result;
        }

        // Initially we check total number of Activities and then start
        // data fetching.
        CRM.api3('Activity', 'getcount', {
          "sequential": 1,
          "is_current_revision": 1,
          "is_deleted": 0,
          "is_test": 0,
        }).done(function(result) {
          var total = parseInt(result.result, 10);
          if (total > 5000) {
            console.info('There is more than 5000 Activities, getting Activities with last month filter.');
            var dateFilterValue = new Date();
            dateFilterValue.setMonth(dateFilterValue.getMonth()-1);
            loadDataByDateFilter(dateFilterValue);
          } else {
            CRM.$('span#activity-report-loading-total').text(total);
            loadData(0, limit, total, 0, 0);
          }
        });

        function loadDataByDateFilter(dateFilterValue) {
          CRM.api3('Activity', 'getcount', {
            "sequential": 1,
            "is_current_revision": 1,
            "is_deleted": 0,
            "is_test": 0,
            "activity_date_time": {">=": dateFilterValue.toISOString().substring(0, 10)}
          }).done(function(result) {
            var total = parseInt(result.result, 10);
            console.info('Total number of Activities within last month: ' + total);
            if (!total) {
              console.info('There is no Activities created within last month.');
            } else {
              CRM.$('span#activity-report-loading-total').text(total);
              loadData(0, limit, total, 0, 0);
            }
          });
        }

        /*
         * Init Pivot Table with given data.
         *
         * @param array data
         */
        function initPivotTable(data) {
          jQuery("#report-pivot-table").pivotUI(data, {
              rendererName: "Table",
              renderers: CRM.$.extend(
                  jQuery.pivotUtilities.renderers, 
                  jQuery.pivotUtilities.c3_renderers,
                  jQuery.pivotUtilities.export_renderers
              ),
              vals: ["Total"],
              rows: [],
              cols: [],
              aggregatorName: "Count",
              unusedAttrsVertical: false,
              rendererOptions: {
                  c3: {
                      size: {
                          width: parseInt(jQuery('#report-pivot-table').width() * 0.78, 10)
                      }
                  },
              },
              derivedAttributes: {
                  "Activity Date": jQuery.pivotUtilities.derivers.dateFormat("Activity Date Time", "%y-%m-%d"),
                  "Activity Start Date Months": jQuery.pivotUtilities.derivers.dateFormat("Activity Date Time", "%y-%m"),
                  "Activity is a test": function(row) {
                      if (parseInt(row["Activity is a test"], 10) === 0) {
                          return "No";
                      }
                      return "Yes";
                  },
                  "Activity Expire Date": function(row) {
                    if (!row["Expire Date"]) {
                      return "";
                    }
                    var expireDateParts = row["Expire Date"].split(/(\d{1,2})\/(\d{1,2})\/(\d{4})/);
                    return expireDateParts[3] + "-" + expireDateParts[1] + "-" + expireDateParts[2];
                  }
              },
              hiddenAttributes: ["Test", "Expire Date"]
          }, false);
        }
    });
</script>
{/literal}
