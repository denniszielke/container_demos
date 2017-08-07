var apiUrl = '/api/';

angular.module('CalculatorApp', [])
    .controller('CalculatorController',
        function ($scope, $http) {
            $scope.Calculate = function () {
                var postUrl = apiUrl + 'square';
                var config = {
                    headers: {
                        'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8;',
                        'number':  $scope.id
                    }
                };

                $http.post(postUrl, { 'number': $scope.id }, config)
                    .success(function (response) { $scope.result = response});
            }            
        }
    );