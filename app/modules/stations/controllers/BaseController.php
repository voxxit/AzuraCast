<?php
namespace Modules\Stations\Controllers;

use App\Radio\Backend\BackendAbstract;
use App\Radio\Frontend\FrontendAbstract;
use Entity\Station;

class BaseController extends \App\Mvc\Controller
{
    /**
     * @var Station The current active station.
     */
    protected $station;

    /**
     * @var FrontendAbstract
     */
    protected $frontend;

    /**
     * @var BackendAbstract
     */
    protected $backend;

    public function init()
    {
        $station_id = (int)$this->getParam('station');
        $this->station = $this->view->station = $this->em->getRepository(Station::class)->find($station_id);

        if (!($this->station instanceof Station))
            throw new \App\Exception\PermissionDenied;

        $this->frontend = $this->view->frontend = $this->station->getFrontendAdapter($this->di);
        $this->backend = $this->view->backend = $this->station->getBackendAdapter($this->di);

        $this->view->sidebar = $this->view->fetch('common::sidebar');

        parent::init();
    }

    protected function permissions()
    {
        return $this->acl->isAllowed('view station management', $this->station->id);
    }
}