###
# Copyright (C) 2014-2016 Andrey Antukh <niwi@niwi.nz>
# Copyright (C) 2014-2016 Jesús Espino Garcia <jespinog@gmail.com>
# Copyright (C) 2014-2016 David Barragán Merino <bameda@dbarragan.com>
# Copyright (C) 2014-2016 Alejandro Alonso <alejandro.alonso@kaleidos.net>
# Copyright (C) 2014-2016 Juan Francisco Alcántara <juanfran.alcantara@kaleidos.net>
# Copyright (C) 2014-2016 Xavi Julian <xavier.julian@kaleidos.net>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.
#
# File: modules/issues/lightboxes.coffee
###

taiga = @.taiga
bindOnce = @.taiga.bindOnce
debounce = @.taiga.debounce

module = angular.module("taigaIssues")

#############################################################################
## Issue Create Lightbox Directive
#############################################################################

CreateIssueDirective = ($repo, $confirm, $rootscope, lightboxService, $loading, $q, attachmentsService) ->
    link = ($scope, $el, $attrs) ->
        form = $el.find("form").checksley()
        $scope.issue = {}
        $scope.attachments = Immutable.List()

        $scope.$on "issueform:new", (ctx, project)->
            form.reset()

            resetAttachments()

            $el.find(".tag-input").val("")

            lightboxService.open($el)

            $scope.issue = {
                project: project.id
                subject: ""
                status: project.default_issue_status
                type: project.default_issue_type
                priority: project.default_priority
                severity: project.default_severity
                tags: []
            }

        $scope.$on "$destroy", ->
            $el.off()


        createAttachments = (obj) ->
            promises = _.map attachmentsToAdd.toJS(), (attachment) ->
                return attachmentsService.upload(attachment.file, obj.id, $scope.issue.project, 'issue')

            return $q.all(promises)

        attachmentsToAdd = Immutable.List()

        resetAttachments = () ->
            attachmentsToAdd = Immutable.List()
            $scope.attachments = Immutable.List()

        $scope.addAttachment = (attachment) ->
            attachmentsToAdd = attachmentsToAdd.push(attachment)

        submit = debounce 2000, (event) =>
            event.preventDefault()

            if not form.validate()
                return

            currentLoading = $loading()
                .target(submitButton)
                .start()

            promise = $repo.create("issues", $scope.issue)

            promise.then (data) ->
                return createAttachments(data)

            promise.then (data) ->
                currentLoading.finish()
                $rootscope.$broadcast("issueform:new:success", data)
                lightboxService.close($el)
                $confirm.notify("success")

            promise.then null, ->
                currentLoading.finish()
                $confirm.notify("error")


        submitButton = $el.find(".submit-button")

        $el.on "submit", "form", submit


    return {link:link}

module.directive("tgLbCreateIssue", ["$tgRepo", "$tgConfirm", "$rootScope", "lightboxService", "$tgLoading", "$q", "tgAttachmentsService",
                                     CreateIssueDirective])


#############################################################################
## Issue Bulk Create Lightbox Directive
#############################################################################

CreateBulkIssuesDirective = ($repo, $rs, $confirm, $rootscope, $loading, lightboxService) ->
    link = ($scope, $el, attrs) ->
        form = null

        $scope.$on "issueform:bulk", (ctx, projectId, status)->
            form.reset() if form

            lightboxService.open($el)
            $scope.new = {
                projectId: projectId
                bulk: ""
            }

        submit = debounce 2000, (event) =>
            event.preventDefault()

            form = $el.find("form").checksley()
            if not form.validate()
                return

            currentLoading = $loading()
                .target(submitButton)
                .start()

            data = $scope.new.bulk
            projectId = $scope.new.projectId

            promise = $rs.issues.bulkCreate(projectId, data)
            promise.then (result) ->
                currentLoading.finish()
                $rootscope.$broadcast("issueform:new:success", result)
                lightboxService.close($el)
                $confirm.notify("success")

            promise.then null, ->
                currentLoading.finish()
                $confirm.notify("error")

        submitButton = $el.find(".submit-button")

        $el.on "submit", "form", submit

        $scope.$on "$destroy", ->
            $el.off()

    return {link: link}

module.directive("tgLbCreateBulkIssues", ["$tgRepo", "$tgResources", "$tgConfirm", "$rootScope", "$tgLoading",
                                          "lightboxService", CreateBulkIssuesDirective])
